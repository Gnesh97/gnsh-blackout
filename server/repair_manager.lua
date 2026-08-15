--[[
    server/repair_manager.lua

    Multi-Stage Repair System (spec §37, §38, §39, §40, Phase 13).

    Owns the entire repair lifecycle server-side — the client never
    decides anything, it only runs a progress bar and tells the server
    "this stage's timer finished" via a session id the server itself
    issued (server/interaction_manager.lua — same authoritative-session
    pattern server/sabotage.lua already uses).

    STAGE FLOW: OFFLINE -[StartRepair]-> REPAIRING -[N stages]->
    REPAIRING -[last stage done]-> RECOVERING -[recoveryDurationSec]->
    ONLINE. All four of those state values and the two transitions used
    here already exist in server/transformer_manager.lua's
    ALLOWED_TRANSITIONS table (Phase 5) — nothing there needed to change.
    Going ONLINE also already auto-resolves the transformer's active
    incident (the Phase 11 redo's hook) and fires Replication's grid
    recalculation — both reused as-is.

    MATERIALS: Config.Repair.itemsPerCondition is keyed by damage
    CONDITION (spec §39), not by individual stage — there's no spec data
    for a stage-by-stage material split, so materials are checked once at
    RepairManager.StartRepair() and consumed once at completion, not
    doled out per stage.
]]

RepairManager = {}

local activeRepairs = {} -- [transformerId] = { source=, plan=, stageIndex=, incidentId=, doneStages={} }

local function fullStages()
    return Config.Repair.stages
end

local function stagesForCondition(condition)
    return (Config.Repair.stagesByCondition and Config.Repair.stagesByCondition[condition]) or fullStages()
end

-- Pure-ish (only reads TransformerManager's current snapshot) — given a
-- transformer id, returns the stage list + material list for its CURRENT
-- damage condition. Used by both StartRepair and the /repairdebug command.
function RepairManager.GetPlan(transformerId)
    local tr = TransformerManager.GetState(transformerId)
    if not tr then return nil end

    return {
        condition = tr.condition,
        stages = stagesForCondition(tr.condition),
        materials = (Config.Repair.itemsPerCondition and Config.Repair.itemsPerCondition[tr.condition]) or {},
    }
end

local function hasAllMaterials(source, materials)
    for _, m in ipairs(materials) do
        if not Bridge.HasItem(source, m.item, m.amount) then
            return false, m.item
        end
    end
    return true
end

local function refundMaterials(source, materials)
    local refunded = true
    for _, m in ipairs(materials or {}) do
        local ok, added = pcall(Bridge.AddItem, source, m.item, m.amount)
        if not ok or added ~= true then
            refunded = false
            Log.warn('repair material refund failed', {
                player = source,
                item = m.item,
                amount = m.amount,
                error = ok and 'adapter_rejected' or tostring(added),
            })
        end
    end
    return refunded
end

local function consumeMaterials(source, materials)
    local removedItems = {}
    for _, m in ipairs(materials) do
        local ok, removed, reason = pcall(Bridge.RemoveItem, source, m.item, m.amount)
        if not ok or removed ~= true then
            local rollbackOk = refundMaterials(source, removedItems)
            local failureReason = reason or (ok and 'item_remove_failed' or tostring(removed))
            if not rollbackOk then
                failureReason = failureReason .. ':item_rollback_failed'
            end
            return false, m.item, failureReason
        end
        removedItems[#removedItems + 1] = m
    end
    return true
end

local function repairDistance(point)
    return (point and point.interactionRadius)
        or (Config.Repair and Config.Repair.maxInteractionDistance)
        or 5.0
end

-- Release repair session/lock after failed completion. Without cleanup,
-- transformer stays REPAIRING and later attempts report "already repairing".
function RepairManager.CancelRepair(transformerId, reason)
    local repair = activeRepairs[transformerId]
    if not repair then return false end

    if repair.sessionId then
        InteractionManager.CancelSession(repair.source, repair.sessionId)
    end
    activeRepairs[transformerId] = nil

    local state = TransformerManager.GetState(transformerId)
    if state and state.state == Constants.TransformerState.REPAIRING then
        TransformerManager.SetState(transformerId, Constants.TransformerState.OFFLINE,
            reason or 'REPAIR_CANCELLED', { force = true })
    end

    if repair.incidentId then
        IncidentManager.UpdateStatus(repair.incidentId, Constants.IncidentStatus.ACTIVE,
            repair.source, { repairProgress = repair.doneStages })
    end

    Log.event(Constants.LogEvent.REPAIR_FAILED, {
        player = repair.source,
        target = transformerId,
        reason = reason or 'repair_cancelled',
    })
    return true
end

function RepairManager.CancelAll(reason)
    local count = 0
    local ids = {}
    for transformerId in pairs(activeRepairs) do
        ids[#ids + 1] = transformerId
    end
    for _, transformerId in ipairs(ids) do
        if RepairManager.CancelRepair(transformerId, reason or 'REPAIR_ALL') then
            count = count + 1
        end
    end
    return count
end

local function cancelRepairForSession(source, sessionId, reason)
    for transformerId, repair in pairs(activeRepairs) do
        if repair.source == source and repair.sessionId == sessionId then
            RepairManager.CancelRepair(transformerId, reason)
            return true
        end
    end
    return false
end

function RepairManager.StartRepair(source, transformerId)
    if not Config.Repair or not Config.Repair.enabled then
        return false, 'Tamir sistemi kapalı.'
    end

    local validTarget, targetTypeOrError, normalizedTargetId = Security.ValidateTarget(Constants.ComponentType.TRANSFORMER, transformerId)
    if not validTarget then
        return false, targetTypeOrError
    end
    transformerId = normalizedTargetId

    local trConfig = Transformers[transformerId]
    local worldPoint = InfrastructureWorld and InfrastructureWorld[transformerId]
    if not trConfig or not worldPoint or not worldPoint.enabled or not worldPoint.coords then
        return false, 'Geçersiz trafo hedefi.'
    end

    local trState = TransformerManager.GetState(transformerId)
    if not trState or trState.damage <= 0 then
        return false, 'Bu trafo hasarlı değil, tamire gerek yok.'
    end

    if activeRepairs[transformerId] then
        return false, 'Bu trafo zaten tamir ediliyor.'
    end

    if Config.Repair.requiredJob then
        local job = Bridge.GetJob(source)
        if job ~= Config.Repair.requiredJob then
            return false, 'Bu tamiri yapabilecek yetkiniz yok.'
        end
    end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then
        return false, 'Geçersiz oyuncu.'
    end

    local dist = #(GetEntityCoords(ped) - worldPoint.coords)
    local maxDist = repairDistance(worldPoint)
    if dist > maxDist then
        return false, 'Trafoya çok uzaksınız.'
    end

    local plan = RepairManager.GetPlan(transformerId)
    if not plan then
        return false, 'Tamir planı oluşturulamadı.'
    end

    if Config.Repair.requireItem then
        local ok, missingItem = hasAllMaterials(source, plan.materials)
        if not ok then
            return false, ('Gerekli malzeme eksik: %s'):format(missingItem)
        end
    end

    -- OFFLINE -> REPAIRING (legal edge). Reflexive if already REPAIRING
    -- (e.g. a second electrician joining an in-progress repair) — SetState
    -- treats fromState == newState as a no-op success, not an error.
    local okState, stateErr = TransformerManager.SetState(transformerId, Constants.TransformerState.REPAIRING, 'REPAIR_STARTED')
    if not okState then
        return false, stateErr or 'Trafo şu anda tamire uygun durumda değil.'
    end

    local activeIncident = IncidentManager.GetActiveIncidentForTransformer(transformerId)
    if activeIncident then
        IncidentManager.UpdateStatus(activeIncident.incidentId, Constants.IncidentStatus.REPAIRING, source)
    end

    -- Resume from persisted progress if any (spec §38) — a disconnected
    -- electrician's completed stages survive in the incident's metadata.
    local doneStages = {}
    if Config.Repair.persistentRepairProgress and activeIncident and activeIncident.metadata and activeIncident.metadata.repairProgress then
        doneStages = activeIncident.metadata.repairProgress
    end

    local firstPending = #plan.stages + 1
    for i, stageName in ipairs(plan.stages) do
        if not doneStages[stageName] then
            firstPending = i
            break
        end
    end

    activeRepairs[transformerId] = {
        source = source,
        plan = plan,
        originalDamage = trState.damage,
        stageIndex = firstPending,
        incidentId = activeIncident and activeIncident.incidentId or nil,
        doneStages = doneStages,
    }

    Log.event(Constants.LogEvent.REPAIR_STARTED, {
        player = source, target = transformerId, condition = plan.condition, resumedAtStage = firstPending,
    })

    RepairManager.AdvanceStage(transformerId)
    return true, nil
end

-- Starts the interaction session for the repair's current stage, or
-- completes the repair if every stage is already done.
function RepairManager.AdvanceStage(transformerId)
    local repair = activeRepairs[transformerId]
    if not repair then return end

    local stageName = repair.plan.stages[repair.stageIndex]
    if not stageName then
        RepairManager.CompleteRepair(transformerId)
        return
    end

    local minTime = Config.Repair.stageDurationSec or 3
    local sessionId, err = InteractionManager.StartSession(repair.source, 'REPAIR:' .. stageName, transformerId, minTime, 60, {
        targetType = Constants.ComponentType.TRANSFORMER,
        expectedStage = stageName,
        targetRevision = Security.GetTargetRevision(Constants.ComponentType.TRANSFORMER, transformerId),
    })

    if not sessionId then
        RepairManager.CancelRepair(transformerId, 'REPAIR_SESSION_START_FAILED')
        Bridge.Notify(repair.source, err or 'Tamir oturumu başlatılamadı.', 'error')
        Log.event(Constants.LogEvent.REPAIR_FAILED, { player = repair.source, target = transformerId, stage = stageName, reason = err })
        return
    end

    repair.sessionId = sessionId
    if Metrics then Metrics.Inc('server.networkEvent.client') end
    TriggerClientEvent('infra:startRepairStage', repair.source, sessionId, transformerId, stageName, repair.stageIndex, #repair.plan.stages)
end

function RepairManager.CompleteRepair(transformerId)
    local repair = activeRepairs[transformerId]
    if not repair then return end

    local materialsConsumed = false
    if Config.Repair.requireItem then
        local hasMaterials, missingItem = hasAllMaterials(repair.source, repair.plan.materials)
        if not hasMaterials then
            RepairManager.CancelRepair(transformerId, 'REPAIR_MATERIALS_MISSING')
            Bridge.Notify(repair.source, ('Gerekli malzeme eksik: %s'):format(missingItem), 'error')
            return
        end

        local consumed, failedItem, removeError = consumeMaterials(repair.source, repair.plan.materials)
        if not consumed then
            RepairManager.CancelRepair(transformerId, 'REPAIR_MATERIALS_REMOVE_FAILED')
            Log.event(Constants.LogEvent.REPAIR_FAILED, {
                player = repair.source,
                target = transformerId,
                reason = 'item_remove_failed:' .. tostring(removeError),
                item = failedItem,
            })
            Bridge.Notify(repair.source, 'Tamir malzemeleri envanterden düşürülemedi, işlem iptal edildi.', 'error')
            return
        end
        materialsConsumed = true
    end

    -- REPAIRING -> RECOVERING (legal edge). Damage cleared now (materials
    -- have genuinely been spent) but the transformer doesn't reach ONLINE
    -- until the recovery delay below — that's the ONLINE hook's job, and
    -- it's what auto-resolves the incident.
    local stateChanged, stateError = TransformerManager.SetState(
        transformerId,
        Constants.TransformerState.RECOVERING,
        'REPAIR_COMPLETE'
    )
    if not stateChanged then
        if materialsConsumed then refundMaterials(repair.source, repair.plan.materials) end
        RepairManager.CancelRepair(transformerId, 'REPAIR_STATE_TRANSITION_FAILED')
        Bridge.Notify(repair.source, 'Tamir durumu güncellenemedi, işlem iptal edildi.', 'error')
        Log.event(Constants.LogEvent.REPAIR_FAILED, {
            player = repair.source,
            target = transformerId,
            reason = 'state_transition_failed:' .. tostring(stateError),
        })
        return
    end

    local damageCleared, damageError = TransformerManager.SetDamage(transformerId, 0, 'REPAIR_COMPLETE')
    if not damageCleared then
        if materialsConsumed then refundMaterials(repair.source, repair.plan.materials) end
        TransformerManager.SetState(transformerId, Constants.TransformerState.OFFLINE, 'REPAIR_ROLLBACK', { force = true })
        RepairManager.CancelRepair(transformerId, 'REPAIR_DAMAGE_RESET_FAILED')
        Bridge.Notify(repair.source, 'Tamir hasarı sıfırlanamadı, işlem iptal edildi.', 'error')
        Log.event(Constants.LogEvent.REPAIR_FAILED, {
            player = repair.source,
            target = transformerId,
            reason = 'damage_reset_failed:' .. tostring(damageError),
        })
        return
    end

    local originalDamage = repair.originalDamage
    activeRepairs[transformerId] = nil

    Bridge.Notify(repair.source, 'Tamir tamamlandı, sistem yeniden başlatılıyor...', 'success')

    local recoverySec = Config.Repair.recoveryDurationSec or 5
    SetTimeout(recoverySec * 1000, function()
        -- RECOVERING -> ONLINE (legal edge) — fires transformer_manager's
        -- existing ONLINE hook (auto-resolves the incident) and Replication's
        -- grid recalculation. Nothing new needed in either of those modules.
        local current = TransformerManager.GetState(transformerId)
        if current and current.state == Constants.TransformerState.ONLINE then return end

        local online, onlineError = TransformerManager.SetState(
            transformerId,
            Constants.TransformerState.ONLINE,
            'REPAIR_COMPLETE'
        )
        if online then return end

        local rollbackError
        local refunded = not materialsConsumed
        current = TransformerManager.GetState(transformerId)
        if current and current.state == Constants.TransformerState.RECOVERING then
            local restoredDamage, damageError = TransformerManager.SetDamage(
                transformerId,
                originalDamage,
                'REPAIR_RECOVERY_ROLLBACK'
            )
            if not restoredDamage then rollbackError = damageError end

            local offline, offlineError = TransformerManager.SetState(
                transformerId,
                Constants.TransformerState.OFFLINE,
                'REPAIR_RECOVERY_ROLLBACK',
                { force = true }
            )
            if not offline and not rollbackError then rollbackError = offlineError end

            -- Refund only when this recovery still owns the transformer.
            -- An external sabotage/admin mutation may have moved it out of
            -- RECOVERING; that path must not create a free repair reward.
            if materialsConsumed then
                refunded = refundMaterials(repair.source, repair.plan.materials)
            end
        end

        Bridge.Notify(repair.source, 'Tamir kurtarma aşaması başarısız oldu, işlem geri alındı.', 'error')
        Log.event(Constants.LogEvent.REPAIR_FAILED, {
            player = repair.source,
            target = transformerId,
            reason = 'recovery_state_failed:' .. tostring(onlineError),
            rollbackError = rollbackError,
            materialsRefunded = refunded,
        })
    end)
end

RegisterNetEvent('infra:requestRepair', function(transformerId)
    local src = source
    local allowed = Security.AllowEvent(src, 'infra:requestRepair')
    if not allowed then return end
    local validSource = Security.ValidateSource(src)
    if not validSource then return end
    local ok, err = RepairManager.StartRepair(src, transformerId)
    if not ok then
        Bridge.Notify(src, err or 'Tamir başlatılamadı.', 'error')
    end
end)

RegisterNetEvent('infra:submitRepairStage', function(sessionId)
    local src = source

    local allowed = Security.AllowEvent(src, 'infra:submitRepairStage')
    if not allowed then return end
    local validSource = Security.ValidateSource(src)
    if not validSource then return end

    local sessionOk, sessionOrError = Security.ValidateSession(src, sessionId, nil, Constants.ComponentType.TRANSFORMER)
    if not sessionOk then
        cancelRepairForSession(src, sessionId, 'REPAIR_SESSION_INVALID')
        Bridge.Notify(src, 'Tamir doğrulaması başarısız: ' .. tostring(sessionOrError), 'error')
        return
    end
    if not Security.ValidateRevision(Constants.ComponentType.TRANSFORMER, sessionOrError.targetId, sessionOrError.targetRevision) then
        cancelRepairForSession(src, sessionId, 'REPAIR_TARGET_REVISION_CHANGED')
        Bridge.Notify(src, 'Tamir hedefi güncelliğini kaybetti.', 'error')
        return
    end
    local repairPoint = InfrastructureWorld and InfrastructureWorld[sessionOrError.targetId]
    if not repairPoint or not Security.ValidateDistance(src, repairPoint.coords, repairDistance(repairPoint)) then
        cancelRepairForSession(src, sessionId, 'REPAIR_DISTANCE_FAILED')
        Bridge.Notify(src, 'Tamir hedefinden çok uzaktasınız.', 'error')
        return
    end

    local transformerId, repair
    for trId, r in pairs(activeRepairs) do
        if r.sessionId == sessionId and r.source == src then
            transformerId, repair = trId, r
            break
        end
    end
    if not repair then return end

    local expectedStage = repair.plan.stages[repair.stageIndex]
    if sessionOrError.targetId ~= transformerId
        or sessionOrError.action ~= 'REPAIR:' .. expectedStage
        or sessionOrError.expectedStage ~= expectedStage then
        RepairManager.CancelRepair(transformerId, 'REPAIR_STAGE_INVALID')
        Bridge.Notify(src, 'Geçersiz veya eski tamir aşaması.', 'error')
        return
    end

    local ok, sessionOrErr = InteractionManager.ValidateSessionComplete(src, sessionId)
    if not ok then
        RepairManager.CancelRepair(transformerId, 'REPAIR_SESSION_COMPLETION_FAILED')
        Bridge.Notify(src, 'Tamir doğrulaması başarısız: ' .. tostring(sessionOrErr), 'error')
        Log.event(Constants.LogEvent.REPAIR_FAILED, {
            player = src, target = transformerId, stage = repair.plan.stages[repair.stageIndex], reason = sessionOrErr,
        })
        return
    end

    local stageName = repair.plan.stages[repair.stageIndex]
    repair.doneStages[stageName] = true

    if Config.Repair.persistentRepairProgress and repair.incidentId then
        IncidentManager.UpdateStatus(repair.incidentId, Constants.IncidentStatus.REPAIRING, src, { repairProgress = repair.doneStages })
    end

    Log.event(Constants.LogEvent.REPAIR_STAGE_COMPLETE, { player = src, target = transformerId, stage = stageName })

    repair.stageIndex = repair.stageIndex + 1
    RepairManager.AdvanceStage(transformerId)
end)

-- Disconnect mid-repair (spec §40 "Disconnect/death/timeout halinde lock
-- temizlenmelidir"): InteractionManager's own playerDropped handler
-- already frees the session/target lock. This only clears OUR bookkeeping
-- so a NEW StartRepair call isn't blocked by the stale activeRepairs
-- entry — the transformer stays in REPAIRING and progress stays in the
-- incident's metadata (spec §38), so a second electrician resumes rather
-- than starting over.
RegisterNetEvent('infra:cancelRepairStage', function(sessionId)
    local src = source

    local allowed = Security.AllowEvent(src, 'infra:cancelRepairStage')
    if not allowed then return end
    local validSource = Security.ValidateSource(src)
    if not validSource then return end

    -- Cancellation is idempotent. Source/session matching inside the helper
    -- prevents one player from cancelling another player's repair.
    cancelRepairForSession(src, sessionId, 'REPAIR_CLIENT_CANCELLED')
end)

AddEventHandler('playerDropped', function()
    local src = source
    for trId, r in pairs(activeRepairs) do
        if r.source == src then
            activeRepairs[trId] = nil
            Log.event(Constants.LogEvent.REPAIR_FAILED, { player = src, target = trId, reason = 'player_dropped' })
            break
        end
    end
end)
