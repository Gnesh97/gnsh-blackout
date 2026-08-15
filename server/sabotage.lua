--[[
    server/sabotage.lua

    Sabotage System (spec §33, §34, §36, §44, Phase 12).

    Handles server validation of sabotage attempts (Thermite, C4), item
    usage verification, interaction session validation, damage
    application, explosion effects broadcast, and incident creation.

    SECURITY NOTE (spec §36): the client never gets to assert "what
    sabotage type I used" after the fact — the TYPE is fixed at
    `requestSabotage` time and carried authoritatively through the
    InteractionManager session's `action` field. `submitSabotageResult`
    only reads that server-recorded action, never a client-supplied type
    string. This closes the Phase 12 redo's item/damage-mismatch bug
    (a player could previously get charged the wrong item for the wrong
    method).
]]

Sabotage = {}

local cooldowns = {} -- [transformerId] = os.time() the cooldown expires

local function isOnCooldown(targetId)
    local expiresAt = cooldowns[targetId]
    return expiresAt ~= nil and os.time() < expiresAt
end

local function startCooldown(targetId)
    local cooldownSec = (Config.Sabotage and Config.Sabotage.cooldownSec) or 30
    cooldowns[targetId] = os.time() + cooldownSec
end

local function consumeItem(source, item, amount)
    local ok, removed, reason = pcall(Bridge.RemoveItem, source, item, amount)
    if not ok or removed ~= true then
        return false, reason or 'item_remove_failed'
    end
    return true
end

RegisterNetEvent('infra:requestSabotage', function(targetId, sabotageType)
    local src = source
    local allowed, sourceOrError = Security.AllowEvent(src, 'infra:requestSabotage')
    if not allowed then return end
    local validSource, normalizedSource = Security.ValidateSource(src)
    if not validSource then return end
    local validTarget, targetTypeOrError, normalizedTargetId = Security.ValidateTarget(Constants.ComponentType.TRANSFORMER, targetId)
    if not validTarget then
        Bridge.Notify(src, targetTypeOrError, 'error')
        return
    end
    local validType, normalizedType = Security.ValidateString(sabotageType, 'sabotageType')
    if not validType then
        Bridge.Notify(src, normalizedType, 'error')
        return
    end
    targetId = normalizedTargetId
    sabotageType = normalizedType
    if not Config.Sabotage or not Config.Sabotage.enabled then
        Bridge.Notify(src, 'Sabotaj sistemi kapalı.', 'error')
        return
    end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end

    local trConfig = Transformers[targetId]
    local worldPoint = InfrastructureWorld and InfrastructureWorld[targetId]
    if not trConfig or not worldPoint or not worldPoint.enabled then
        Bridge.Notify(src, 'Geçersiz trafo hedefi.', 'error')
        return
    end

    -- Sabotage type config check (spec §33 — only THERMITE/C4 implemented)
    local cfg = Config.Sabotage and Config.Sabotage.items and Config.Sabotage.items[sabotageType]
    if not cfg then
        Bridge.Notify(src, 'Geçersiz sabotaj türü.', 'error')
        return
    end

    -- State check: cannot sabotage a destroyed/offline transformer
    local trState = TransformerManager.GetState(targetId)
    if not trState or trState.state == Constants.TransformerState.OFFLINE or trState.condition == Constants.Condition.DESTROYED then
        Bridge.Notify(src, 'Bu trafo zaten devre dışı veya patlamış durumda.', 'error')
        return
    end

    -- Cooldown check (spec §44 SABOTAGE cooldown category)
    if isOnCooldown(targetId) then
        Bridge.Notify(src, 'Bu trafo kısa süre önce sabote edildi, tekrar denemeden önce bekleyin.', 'error')
        return
    end

    -- Distance check
    local playerCoords = GetEntityCoords(ped)
    local targetCoords = worldPoint.coords
    if not targetCoords then
        Bridge.Notify(src, 'Trafo dünya yerleşimi eksik.', 'error')
        return
    end
    local maxDist = (Config.Sabotage and Config.Sabotage.maxInteractionDistance) or 5.0
    local inRange, rangeError = Security.ValidateDistance(src, targetCoords, maxDist)
    if not inRange then
        Bridge.Notify(src, rangeError, 'error')
        return
    end

    -- Item requirement check via Bridge
    if Config.Sabotage and Config.Sabotage.requireItem then
        local hasItem = Bridge.HasItem(src, cfg.item, 1)
        if not hasItem then
            Bridge.Notify(src, ('Sabotaj için gerekli eşyanız yok (%s).'):format(cfg.item), 'error')
            return
        end
    end

    -- Start secure interaction session — `sabotageType` (not a generic
    -- 'SABOTAGE' constant) becomes the session's authoritative `action`,
    -- so submitSabotageResult can trust it without re-validating a
    -- client-supplied type.
    local minTime = (Config.Sabotage and Config.Sabotage.minCompletionTime) or 3
    local maxTimeout = (Config.Sabotage and Config.Sabotage.sessionTimeout) or 60
    local sessionId, err = InteractionManager.StartSession(src, sabotageType, targetId, minTime, maxTimeout, {
        targetType = Constants.ComponentType.TRANSFORMER,
        targetRevision = Security.GetTargetRevision(Constants.ComponentType.TRANSFORMER, targetId),
    })

    if not sessionId then
        Bridge.Notify(src, err or 'Etkileşim başlatılamadı.', 'error')
        return
    end

    Log.event(Constants.LogEvent.SABOTAGE_STARTED, {
        player = src,
        target = targetId,
        sabotageType = sabotageType,
        sessionId = sessionId,
    })

    if Metrics then Metrics.Inc('server.networkEvent.client') end
    TriggerClientEvent('infra:startSabotageMinigame', src, sessionId, targetId, sabotageType, cfg)
end)

RegisterNetEvent('infra:submitSabotageResult', function(sessionId, success)
    local src = source

    local allowed = Security.AllowEvent(src, 'infra:submitSabotageResult')
    if not allowed then return end
    local validSource = Security.ValidateSource(src)
    if not validSource then return end
    local sessionOk, sessionOrError = Security.ValidateSession(src, sessionId, nil, Constants.ComponentType.TRANSFORMER)
    if not sessionOk then
        Bridge.Notify(src, 'Sabotaj doğrulaması başarısız: ' .. tostring(sessionOrError), 'error')
        return
    end
    local pendingSession = sessionOrError
    if type(success) ~= 'boolean' then
        InteractionManager.CancelSession(src, sessionId)
        Bridge.Notify(src, 'Geçersiz sabotaj sonucu.', 'error')
        return
    end
    if not Security.ValidateRevision(Constants.ComponentType.TRANSFORMER, pendingSession.targetId, pendingSession.targetRevision) then
        InteractionManager.CancelSession(src, sessionId)
        Bridge.Notify(src, 'Sabotaj hedefi güncelliğini kaybetti.', 'error')
        return
    end
    local worldPoint = InfrastructureWorld and InfrastructureWorld[pendingSession.targetId]
    if not worldPoint or not Security.ValidateDistance(src, worldPoint.coords, (Config.Sabotage and Config.Sabotage.maxInteractionDistance) or 5.0) then
        InteractionManager.CancelSession(src, sessionId)
        Bridge.Notify(src, 'Sabotaj hedefinden çok uzaktasınız.', 'error')
        return
    end

    -- Validate session and timing (anti-cheat)
    local ok, sessionOrErr = InteractionManager.ValidateSessionComplete(src, sessionId)
    if not ok then
        InteractionManager.CancelSession(src, sessionId)
        Log.event(Constants.LogEvent.SABOTAGE_FAILED, {
            player = src,
            sessionId = sessionId,
            reason = sessionOrErr,
        })
        Bridge.Notify(src, 'Sabotaj doğrulaması başarısız: ' .. tostring(sessionOrErr), 'error')
        return
    end

    local session = sessionOrErr
    local targetId = session.targetId
    local sabotageType = session.action -- authoritative — set at requestSabotage time, never re-trusted from the client

    local trConfig = Transformers[targetId]
    local worldPoint = InfrastructureWorld and InfrastructureWorld[targetId]
    if not trConfig or not worldPoint then return end

    local cfg = Config.Sabotage and Config.Sabotage.items and Config.Sabotage.items[sabotageType]
    if not cfg then
        -- Session action doesn't map to a known sabotage type — shouldn't
        -- happen (requestSabotage already validated it), but fail closed.
        Log.event(Constants.LogEvent.SABOTAGE_FAILED, { player = src, target = targetId, reason = 'unknown session action: ' .. tostring(sabotageType) })
        return
    end

    -- A validated sabotage attempt consumes one configured item regardless
    -- of skillcheck result. Failed skillchecks still create no damage,
    -- incident, or success cooldown.
    local itemConsumed = false
    if Config.Sabotage and Config.Sabotage.requireItem then
        local removed, removeError = consumeItem(src, cfg.item, 1)
        if not removed then
            Log.event(Constants.LogEvent.SABOTAGE_FAILED, {
                player = src,
                target = targetId,
                sabotageType = sabotageType,
                reason = 'item_remove_failed:' .. tostring(removeError),
            })
            Bridge.Notify(src, 'Sabotaj eşyası envanterden düşürülemedi, işlem iptal edildi.', 'error')
            return
        end
        itemConsumed = true
    end

    if success then

        startCooldown(targetId)
        Bridge.Notify(src, ('%s yerleştirildi, birazdan patlayacak...'):format(cfg.label or sabotageType), 'success')

        -- Detonation is delayed (fuse timer), not instant — the player
        -- has already walked away from the animation by the time the
        -- minigame result comes back, so an immediate boom read as
        -- broken/too fast in live testing. Damage/incident/explosion all
        -- fire together after the delay; item consumption above stays
        -- immediate (you used the item the moment you planted it).
        SetTimeout(5000, function()
            local damageAmount = cfg.damage or 100

            -- Apply damage to transformer
            TransformerManager.SetDamage(targetId, damageAmount, 'SABOTAGE', {
                source = src,
                cause = Constants.IncidentCause.SABOTAGE,
                severity = damageAmount,
            })

            Log.event(Constants.LogEvent.SABOTAGE_SUCCESS, {
                player = src,
                target = targetId,
                damage = damageAmount,
                sabotageType = sabotageType,
            })

            -- Broadcast explosion PTFX & sound to clients
            if Metrics then Metrics.Inc('server.networkEvent.broadcast') end
            TriggerClientEvent('infra:playExplosion', -1, worldPoint.coords)
        end)
    else
        Log.event(Constants.LogEvent.SABOTAGE_FAILED, {
            player = src,
            target = targetId,
            sabotageType = sabotageType,
            reason = 'minigame_failed',
            itemConsumed = itemConsumed,
        })

        Bridge.Notify(src, 'Sabotaj başarısız oldu!', 'error')
    end
end)
