--[[
    server/debug.lua

    Admin/dev tooling (spec §63). Read-only commands (griddebug,
    showtransformers, powerdebug) are open to any player when
    Config.Debug.enabled is true — they only print state that's already
    replicated to every client anyway. State-MUTATING commands
    (setgridpower, setdamage) require Config.Debug.adminGroup permission,
    checked via Bridge.HasPermission — server console (source 0) always
    passes.

    /setgridpower is the primary tool for the Phase 8 acceptance scenario
    (spec §75): force a grid on/off without needing the full sabotage flow
    that doesn't exist until Phase 12.
]]

if not Config.IsDebugEnabled() then return end

local districtAuditAt = {}

local function isAllowed(source)
    local allowed = Security.RequireAdmin(source)
    return allowed == true
end

local function printApiQueryResult(source, value, err)
    if err then
        local message = '[gnsh-blackout] API error: ' .. tostring(err)
        print(message)
        if source ~= 0 then Bridge.Notify(source, tostring(err), 'error') end
        return
    end

    local encoded
    if type(json) == 'table' and type(json.encode) == 'function' then
        local ok, result = pcall(json.encode, value)
        encoded = ok and result or nil
    end
    encoded = encoded or tostring(value)
    print('[gnsh-blackout] API result: ' .. encoded)
    if source ~= 0 then
        Bridge.Notify(source, 'API sonucu server konsoluna yazıldı.', 'info')
    end
end

RegisterCommand('apiquery', function(source, args)
    if not isAllowed(source) then return end

    local query = args[1] and string.lower(args[1]) or nil
    local value, err

    if query == 'feeder' then
        value, err = InfrastructureApi.GetFeederState(args[2])
    elseif query == 'substation' then
        value, err = InfrastructureApi.GetSubstationState(args[2])
    elseif query == 'grid' then
        value, err = InfrastructureApi.GetGridState(args[2])
    elseif query == 'district' or query == 'path' then
        value, err = InfrastructureApi.GetPowerPathForDistrict(args[2])
    elseif query == 'position' then
        value, err = InfrastructureApi.GetInfrastructureAtPosition({
            x = tonumber(args[2]),
            y = tonumber(args[3]),
            z = tonumber(args[4]),
        })
    elseif query == 'affected' then
        value, err = InfrastructureApi.GetAffectedDistricts(args[2], args[3])
    elseif query == 'incidents' then
        value, err = InfrastructureApi.GetActiveIncidents()
    else
        err = 'usage: apiquery feeder|substation|grid <id> | path <districtId> | position <x> <y> <z> | affected <targetType> <targetId> | incidents'
    end

    printApiQueryResult(source, value, err)
end, false)

local function printGridDebug(gridId)
    local grid = Grids[gridId]
    if not grid then
        print(('[gnsh-blackout] unknown grid "%s"'):format(tostring(gridId)))
        return
    end

    local state = Replication.GetGridState(gridId) or { powered = true, level = 1.0, status = 'UNKNOWN', revision = -1 }

    print(('[gnsh-blackout] ── Grid Debug: %s ──'):format(gridId))
    print(('  Label:      %s'):format(grid.label))
    print(('  Power:      %s'):format(state.powered and 'ON' or 'OFF'))
    print(('  Power Level: %.2f'):format(state.level))
    print(('  Status:     %s'):format(state.status))
    print(('  Revision:   %d'):format(state.revision))
    if state.blockedBy then
        print(('  Blocked by: %s/%s'):format(state.blockedBy.type, state.blockedBy.id))
    end
    print(('  Districts:  %s'):format(table.concat(grid.districts, ', ')))

    for _, subId in ipairs(grid.substations) do
        local subState = SubstationManager.GetState(subId)
        print(('  Substation: %s (status=%s, %d/%d online)'):format(subId, subState.status, subState.onlineTransformers, subState.totalTransformers))
        local sub = Substations[subId]
        for _, trId in ipairs(sub.transformers) do
            local tr = TransformerManager.GetState(trId)
            print(('    Transformer: %s  state=%s  condition=%s  damage=%d'):format(trId, tr.state, tr.condition, tr.damage))
        end
    end
end

RegisterCommand('griddebug', function(source, args)
    local gridId = args[1]
    if not gridId then
        for _, id in ipairs(GridManager.GetAllGridIds()) do
            printGridDebug(id)
        end
    else
        printGridDebug(gridId)
    end
end, false)

RegisterCommand('showtransformers', function(_source)
    for _, id in ipairs(TransformerManager.GetAllIds()) do
        local tr = TransformerManager.GetState(id)
        local blockedBy = FailureManager.GetBlockingAncestor(Constants.ComponentType.TRANSFORMER, id)
        local blockedText = blockedBy and (' blockedBy=%s/%s'):format(blockedBy.type, blockedBy.id) or ''
        print(('[gnsh-blackout] %s  state=%s  condition=%s  damage=%d%s'):format(id, tr.state, tr.condition, tr.damage, blockedText))
    end
end, false)

local function setComponentState(source, args, targetType, usage)
    if not isAllowed(source) then return end

    local targetId = args[1]
    local desired = args[2] and string.upper(args[2]) or nil
    if not targetId or (desired ~= Constants.ComponentState.ONLINE and desired ~= Constants.ComponentState.OFFLINE) then
        local msg = 'usage: ' .. usage
        if source == 0 then print(msg) else Bridge.Notify(source, msg, 'error') end
        return
    end

    local ok, err = FailureManager.SetState(targetType, targetId, desired, 'admin:' .. targetType .. ':state', source)
    if source == 0 then
        print(ok and ('[gnsh-blackout] %s/%s = %s'):format(targetType, targetId, desired)
            or ('[gnsh-blackout] ' .. tostring(err)))
    elseif not ok then
        Bridge.Notify(source, tostring(err), 'error')
    else
        Bridge.Notify(source, ('%s %s: %s'):format(targetType, targetId, desired), 'success')
    end
end

RegisterCommand('showincidents', function(source)
    local incidents = IncidentManager.GetAllActiveIncidents()
    if #incidents == 0 then
        local msg = '[gnsh-blackout] Aktif olay (incident) bulunmuyor.'
        if source == 0 then print(msg) else Bridge.Notify(source, msg, 'info') end
        return
    end
    print('[gnsh-blackout] ── Aktif Olaylar (Incidents) ──')
    for _, inc in ipairs(incidents) do
        local impact = inc.estimatedImpact or {}
        local districts = inc.affectedDistricts or inc.districts or {}
        print(('  ID: %s  Hedef: %s/%s  Grid: %s  Feeder: %s  Neden: %s  Durum: %s'):format(
            inc.incidentId,
            tostring(inc.targetType),
            tostring(inc.targetId),
            tostring(inc.gridId),
            tostring(inc.feederId),
            tostring(inc.cause),
            tostring(inc.status)))
        print(('    Districtler: %s  Etki: %d district / %d oyuncu  Severity: %s'):format(
            table.concat(districts, ', '),
            impact.districtCount or #districts,
            impact.playerCount or 0,
            tostring(inc.severity)))
    end
end, false)

RegisterCommand('powerdebug', function(_source)
    for _, id in ipairs(GridManager.GetAllGridIds()) do
        local state = Replication.GetGridState(id)
        local blockedText = state.blockedBy and (' blockedBy=%s/%s'):format(state.blockedBy.type, state.blockedBy.id) or ''
        print(('[gnsh-blackout] %s  powered=%s  level=%.2f  status=%s  revision=%d'):format(
            id, tostring(state.powered), state.level, state.status, state.revision) .. blockedText)
    end
end, false)

RegisterCommand('setgridpower', function(source, args)
    if not isAllowed(source) then return end

    local gridId = args[1]
    local desired = tonumber(args[2])

    if not gridId or not Grids[gridId] or desired == nil then
        local msg = 'usage: setgridpower <gridId> <0|1>'
        if source == 0 then print(msg) else Bridge.Notify(source, msg, 'error') end
        return
    end

    for _, trId in ipairs(GridManager.GetTransformersForGrid(gridId)) do
        if desired == 0 then
            TransformerManager.SetState(trId, Constants.TransformerState.OFFLINE, 'admin:setgridpower', { force = true })
        else
            -- Admin restore: force undamaged + online, bypassing the
            -- normal REPAIRING/RECOVERING path (that's what a real repair
            -- flow is for, Phase 13 — this is a debug shortcut).
            TransformerManager.SetDamage(trId, 0, 'admin:setgridpower')
            TransformerManager.SetState(trId, Constants.TransformerState.ONLINE, 'admin:setgridpower', { force = true })
        end
    end

    Log.event(Constants.LogEvent.INTERACTION_CREATED, { command = 'setgridpower', gridId = gridId, desired = desired, source = source })
end, false)

RegisterCommand('setdamage', function(source, args)
    if not isAllowed(source) then return end

    local trId = args[1]
    local damage = tonumber(args[2])

    if not trId or not Transformers[trId] or not damage then
        local msg = 'usage: setdamage <transformerId> <0-100>'
        if source == 0 then print(msg) else Bridge.Notify(source, msg, 'error') end
        return
    end

    TransformerManager.SetDamage(trId, damage, 'admin:setdamage', {
        source = source,
        cause = Constants.IncidentCause.ADMIN,
        severity = damage,
    })
end, false)

-- Phase 13: prints the same {stages, materials} shape RepairManager
-- itself uses to start a repair, so testers can check what a trafo needs
-- before walking up to it with /giveitem.
RegisterCommand('repairdebug', function(source, args)
    local trId = args[1]
    if not trId or not Transformers[trId] then
        local msg = 'usage: repairdebug <transformerId>'
        if source == 0 then print(msg) else Bridge.Notify(source, msg, 'error') end
        return
    end

    local plan = RepairManager.GetPlan(trId)
    if not plan then
        print(('[gnsh-blackout] tamir planı yok: %s (trafo bulunamadı)'):format(trId))
        return
    end

    print(('[gnsh-blackout] ── Tamir Planı: %s (condition=%s) ──'):format(trId, plan.condition))
    print('  Aşamalar: ' .. table.concat(plan.stages, ' -> '))
    for _, m in ipairs(plan.materials) do
        print(('  Malzeme: %dx %s'):format(m.amount, m.item))
    end
end, false)

-- Admin shortcut: instantly clears damage and forces ONLINE, bypassing
-- the whole stage flow — for testing the REST of the system (incident
-- resolve, grid recalculation) without repeatedly grinding stages.
RegisterCommand('forcerepair', function(source, args)
    if not isAllowed(source) then return end

    local trId = args[1]
    if not trId or not Transformers[trId] then
        local msg = 'usage: forcerepair <transformerId>'
        if source == 0 then print(msg) else Bridge.Notify(source, msg, 'error') end
        return
    end

    TransformerManager.SetDamage(trId, 0, 'admin:forcerepair')
    TransformerManager.SetState(trId, Constants.TransformerState.ONLINE, 'admin:forcerepair', { force = true })
end, false)

-- Test helper: neither qb-core nor ox_inventory ship a bare chat command
-- to give yourself an item on this server (grepped both — none exist),
-- so sabotage/repair testing had no way to hand a player `thermite` /
-- `plastic` / repair materials without opening a UI. Admin-gated, mirrors
-- setgridpower/setdamage's pattern.
RegisterCommand('giveitem', function(source, args)
    if not isAllowed(source) then return end

    local target = tonumber(args[1])
    local item = args[2]
    local amount = tonumber(args[3]) or 1

    if not target or not item then
        local msg = 'usage: giveitem <playerId> <item> [amount]'
        if source == 0 then print(msg) else Bridge.Notify(source, msg, 'error') end
        return
    end

    local ok = Bridge.AddItem(target, item, amount)
    local msg = ok and ('%dx %s verildi (oyuncu %d).'):format(amount, item, target)
        or ('item verilemedi: %s (oyuncu %d) — geçersiz item adı olabilir.'):format(item, target)
    if source == 0 then print('[gnsh-blackout] ' .. msg) else Bridge.Notify(source, msg, ok and 'success' or 'error') end
end, false)

-- Server half of /districtaudit (client/debug.lua). Compares the client's
-- native-based district resolution against the server's AABB
-- approximation and logs a mismatch (see shared/districts.lua header
-- comment for why this tool exists).
RegisterNetEvent('gnsh-blackout:server:districtAudit', function(coords, clientDistrict)
    local src = source
    local allowed = Security.AllowEvent(src, 'gnsh-blackout:server:districtAudit', nil, Config.Security.auditWindowSec)
    if not allowed then return end
    if clientDistrict ~= nil then
        local validDistrict = Security.ValidateString(clientDistrict, 'clientDistrict')
        if not validDistrict then return end
    end

    -- Do not trust client-supplied coordinates for a diagnostic that is
    -- meant to compare the player's real location. The event remains
    -- read-only, but the server-side ped position prevents log spam and
    -- fabricated audit results.
    local ped = GetPlayerPed(src)
    if not ped or ped <= 0 then return end
    local serverCoords = GetEntityCoords(ped)
    local serverDistrict = ServerZone.ResolveDistrict(serverCoords)
    local match = serverDistrict == clientDistrict

    if not match then
        Log.event(Constants.LogEvent.DISTRICT_AUDIT_MISMATCH, {
            source = src, client = clientDistrict, server = serverDistrict or 'nil',
        })
    end

    TriggerClientEvent('gnsh-blackout:client:districtAuditResult', src, clientDistrict, serverDistrict, match)
end)

-- ── Phase 18 additions (§18, §22.3, §24.1) ──────────────────────────────

-- Feeder view — id, substation, transformers, districts, and the
-- currently derived power state (same PowerCalculator.Calculate() a grid
-- uses, just scoped to the feeder's own transformers).
RegisterCommand('showfeeders', function(_source, args)
    local filterGridId = args[1]

    for _, feederId in ipairs(GridManager.GetAllFeederIds()) do
        local feeder = Feeders[feederId]
        local subGridId = GridManager.GetGridForSubstation(feeder.substationId)
        if not filterGridId or filterGridId == subGridId then
            local fs = FeederManager.GetState(feederId)
            print(('[gnsh-blackout] %s  grid=%s  substation=%s  powered=%s  level=%.2f  status=%s'):format(
                feederId, tostring(subGridId), feeder.substationId, tostring(fs.powered), fs.level, fs.status))
            if fs.blockedBy then
                print(('    blockedBy: %s/%s'):format(fs.blockedBy.type, fs.blockedBy.id))
            end
            print(('    trafolar: %s'):format(table.concat(feeder.transformers, ', ')))
            print(('    district\'ler: %s'):format(table.concat(feeder.districts, ', ')))
        end
    end
end, false)

RegisterCommand('showsubstations', function(_source)
    for _, substationId in ipairs(SubstationManager.GetAllIds()) do
        local state = SubstationManager.GetState(substationId)
        local blockedText = state.blockedBy and (' blockedBy=%s/%s'):format(state.blockedBy.type, state.blockedBy.id) or ''
        print(('[gnsh-blackout] %s  grid=%s  powered=%s  level=%.2f  status=%s%s'):format(
            substationId, state.gridId, tostring(state.powered), state.level, state.status, blockedText))
        print(('    transformers: %d/%d online'):format(state.onlineTransformers, state.totalTransformers))
    end
end, false)

-- District-level power view (spec §18's whole point made visible) —
-- optionally filtered by shared/districts.lua's `category` field.
RegisterCommand('showdistrictpower', function(_source, args)
    local filterCategory = args[1]
    local codes = {}
    for code in pairs(Districts.ByCode) do codes[#codes + 1] = code end
    table.sort(codes)

    for _, code in ipairs(codes) do
        local entry = Districts.ByCode[code]
        if entry.enabled and (not filterCategory or entry.category == filterCategory) then
            local state = Replication.GetDistrictState(code)
            if state then
                local sourceText = state.sourceFeederId and (' source=%s'):format(state.sourceFeederId) or ''
                local blockedText = state.blockedBy and (' blockedBy=%s/%s'):format(state.blockedBy.type, state.blockedBy.id) or ''
                print(('[gnsh-blackout] %s (%s)  powered=%s  level=%.2f  status=%s  revision=%d%s%s'):format(
                    code, entry.label, tostring(state.powered), state.level, state.status, state.revision, sourceText, blockedText))
            end
        end
    end
end, false)

-- Full topology chain for one district (spec §24.1 GetPowerPathForDistrict,
-- surfaced early as a debug command since it's the fastest way to
-- eyeball-verify the feeder layer without reading GlobalState by hand).
RegisterCommand('powerpath', function(source, args)
    local code = args[1]
    if not code or not Districts.Exists(code) then
        local msg = 'usage: powerpath <districtId>'
        if source == 0 then print(msg) else Bridge.Notify(source, msg, 'error') end
        return
    end

    local gridId = GridManager.GetGridForDistrict(code)
    if not gridId then
        print(('[gnsh-blackout] %s: %s (grid ataması yok)'):format(code, Districts.GetAssignment(code)))
        return
    end

    print(('[gnsh-blackout] ── Power Path: %s ──'):format(code))
    print(('  GRID: %s'):format(gridId))
    local gridBlock = FailureManager.GetBlockingAncestor(Constants.ComponentType.GRID, gridId)
    if gridBlock then
        print(('  GRID BLOCKED BY: %s/%s'):format(gridBlock.type, gridBlock.id))
    end

    local grid = Grids[gridId]
    for _, subId in ipairs(grid.substations) do
        print(('    SUBSTATION: %s'):format(subId))
        local subBlock = FailureManager.GetBlockingAncestor(Constants.ComponentType.SUBSTATION, subId)
        if subBlock then
            print(('      BLOCKED BY: %s/%s'):format(subBlock.type, subBlock.id))
        end
        local feederIds = GridManager.GetFeedersForSubstation(subId)
        for _, feederId in ipairs(feederIds) do
            local feeder = Feeders[feederId]
            local servesThisDistrict = false
            for _, c in ipairs(feeder.districts) do
                if c == code then servesThisDistrict = true end
            end
            local marker = servesThisDistrict and ' <-- bu district' or ''
            print(('      FEEDER: %s%s'):format(feederId, marker))
            local feederBlock = FailureManager.GetBlockingAncestor(Constants.ComponentType.FEEDER, feederId)
            if feederBlock then
                print(('        BLOCKED BY: %s/%s'):format(feederBlock.type, feederBlock.id))
            end
            for _, trId in ipairs(feeder.transformers) do
                print(('        TRANSFORMER: %s'):format(trId))
            end
        end
    end

    local districtFeeders = GridManager.GetFeedersForDistrict(code)
    if #districtFeeders == 0 then
        print(('  DISTRICT %s: feeder yok, grid seviyesinden besleniyor (fallback)'):format(code))
    end
    print(('  DISTRICT: %s'):format(code))
end, false)

-- Runtime re-run of Validators.ValidateAll(), separate from boot() so an
-- admin can re-check topology after a `refresh` without a full restart.
RegisterCommand('topologyaudit', function(source)
    local ok, errors, warnings = Validators.ValidateAll()

    print(('[gnsh-blackout] ── Topology Audit — %s ──'):format(ok and 'OK' or 'FAILED'))
    for _, err in ipairs(errors) do
        print('  ✗ ERROR: ' .. err)
    end
    for _, warn in ipairs(warnings or {}) do
        print('  ⚠ WARNING: ' .. warn)
    end
    if ok and #(warnings or {}) == 0 then
        print('  Temiz — hata veya uyarı yok.')
    end
end, false)

-- Phase 22 world-placement audit. Server prints the authoritative static
-- registry and current logical state; a player invocation also asks that
-- player's client to validate distance, nearby model and native district.
local function printInfrastructurePoint(point)
    local stateText = 'state=n/a'
    if point.type == 'transformer' then
        local state = TransformerManager.GetState(point.logicalId)
        local blockedBy = FailureManager.GetBlockingAncestor(Constants.ComponentType.TRANSFORMER, point.logicalId)
        stateText = state and ('state=%s condition=%s damage=%d'):format(state.state, state.condition, state.damage) or 'state=unknown'
        if blockedBy then stateText = stateText .. (' blockedBy=%s/%s'):format(blockedBy.type, blockedBy.id) end
    elseif point.type == 'substation' then
        local state = SubstationManager.GetState(point.logicalId)
        stateText = state and ('state=%s powered=%s'):format(state.status, tostring(state.powered)) or 'state=unknown'
    end

    local coords = point.coords
    print(('[gnsh-blackout] %s type=%s enabled=%s coords=(%.1f, %.1f, %.1f) heading=%.1f %s'):format(
        point.logicalId,
        point.type,
        tostring(point.enabled),
        coords.x, coords.y, coords.z,
        point.heading or 0.0,
        stateText
    ))
    print(('    grid=%s substation=%s feeder=%s model=%s interaction=%.1f visual=%.1f districts=%s'):format(
        tostring(point.gridId),
        tostring(point.substationId),
        tostring(point.feederId),
        tostring(point.model),
        point.interactionRadius,
        point.visualRadius,
        table.concat(point.expectedDistricts or {}, ', ')
    ))
end

RegisterCommand('showinfrastructure', function(source, args)
    local requestedId = args[1]
    if requestedId and not InfrastructureWorld[requestedId] then
        local msg = ('unknown infrastructure placement "%s"'):format(requestedId)
        if source == 0 then print('[gnsh-blackout] ' .. msg) else Bridge.Notify(source, msg, 'error') end
        return
    end

    print('[gnsh-blackout] ── Infrastructure World Placement ──')
    if requestedId then
        printInfrastructurePoint(InfrastructureWorld[requestedId])
    else
        local ids = {}
        for logicalId in pairs(InfrastructureWorld) do ids[#ids + 1] = logicalId end
        table.sort(ids)
        for _, logicalId in ipairs(ids) do
            printInfrastructurePoint(InfrastructureWorld[logicalId])
        end
    end

    if source ~= 0 then
        TriggerClientEvent('gnsh-blackout:client:showInfrastructure', source, requestedId)
    end
end, false)
