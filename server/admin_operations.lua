--[[
    server/admin_operations.lua

    Phase 30 operations gateway. Every mutation takes an explicit target,
    passes the central Security gateway, and emits a structured audit event.
    This file is intentionally independent from server/debug.lua so the
    production debug switch can be off while safe admin operations remain.
]]

AdminOperations = {
    CommandNames = {
        'setgridstate', 'setsubstationstate', 'setfeederstate',
        'restoregrid', 'restoresubstation', 'restorefeeder',
        'restoretransformer', 'createincident', 'resolveincident',
        'reloadtopology', 'resyncvisual', 'repairall',
    },
}

local function reply(source, message, kind)
    if source == 0 then
        print('[gnsh-blackout] ' .. tostring(message))
    elseif Bridge and Bridge.Notify then
        Bridge.Notify(source, tostring(message), kind or 'info')
    end
end

local function admin(source, action)
    if not Security.RequireAdmin(source) then
        Log.event(Constants.LogEvent.SECURITY_REJECTED, { source = source, action = action })
        reply(source, 'Bu işlem için yetkiniz yok.', 'error')
        return false
    end
    return true
end

local function audit(source, action, data)
    local payload = data or {}
    payload.action = action
    payload.source = source
    Log.event(Constants.LogEvent.ADMIN_ACTION, payload)
end

local function explicitTarget(source, targetType, targetId, usage)
    if not targetId then
        reply(source, 'usage: ' .. usage, 'error')
        return nil
    end
    local ok, normalizedType, normalizedId = Security.ValidateTarget(targetType, targetId)
    if not ok then
        reply(source, normalizedType, 'error')
        return nil
    end
    return normalizedType, normalizedId
end

local function setState(source, args, targetType, usage)
    local action = 'set' .. targetType .. 'state'
    if not admin(source, action) then return end

    local normalizedType, targetId = explicitTarget(source, targetType, args[1], usage)
    local state = args[2] and string.upper(args[2]) or nil
    if not normalizedType or (state ~= Constants.ComponentState.ONLINE and state ~= Constants.ComponentState.OFFLINE) then
        reply(source, 'usage: ' .. usage, 'error')
        return
    end

    local ok, err = FailureManager.SetState(normalizedType, targetId, state, 'admin:' .. action, source, {
        cause = Constants.IncidentCause.ADMIN,
        severity = state == Constants.ComponentState.OFFLINE and 100 or 0,
    })
    audit(source, action, { targetType = normalizedType, targetId = targetId, state = state, success = ok == true })
    reply(source, ok and (('%s/%s = %s'):format(normalizedType, targetId, state)) or err, ok and 'success' or 'error')
end

local function restore(source, args, targetType, command, usage)
    if not admin(source, command) then return end
    local normalizedType, targetId = explicitTarget(source, targetType, args[1], usage)
    if not normalizedType then return end

    local ok, err = FailureManager.Restore(normalizedType, targetId, 'admin:' .. command, source)
    audit(source, command, { targetType = normalizedType, targetId = targetId, success = ok == true })
    reply(source, ok and (('%s/%s restored'):format(normalizedType, targetId)) or err, ok and 'success' or 'error')
end

RegisterCommand('setgridstate', function(source, args)
    setState(source, args, Constants.ComponentType.GRID, 'setgridstate <gridId> <ONLINE|OFFLINE>')
end, false)

RegisterCommand('setsubstationstate', function(source, args)
    setState(source, args, Constants.ComponentType.SUBSTATION, 'setsubstationstate <substationId> <ONLINE|OFFLINE>')
end, false)

RegisterCommand('setfeederstate', function(source, args)
    setState(source, args, Constants.ComponentType.FEEDER, 'setfeederstate <feederId> <ONLINE|OFFLINE>')
end, false)

RegisterCommand('restoregrid', function(source, args)
    restore(source, args, Constants.ComponentType.GRID, 'restoregrid', 'restoregrid <gridId>')
end, false)

RegisterCommand('restoresubstation', function(source, args)
    restore(source, args, Constants.ComponentType.SUBSTATION, 'restoresubstation', 'restoresubstation <substationId>')
end, false)

RegisterCommand('restorefeeder', function(source, args)
    restore(source, args, Constants.ComponentType.FEEDER, 'restorefeeder', 'restorefeeder <feederId>')
end, false)

RegisterCommand('restoretransformer', function(source, args)
    if not admin(source, 'restoretransformer') then return end
    local normalizedType, targetId = explicitTarget(source, Constants.ComponentType.TRANSFORMER, args[1], 'restoretransformer <transformerId>')
    if not normalizedType then return end

    RepairManager.CancelRepair(targetId, 'admin:restoretransformer')
    TransformerManager.SetDamage(targetId, 0, 'admin:restoretransformer')
    local ok, err = TransformerManager.SetState(targetId, Constants.TransformerState.ONLINE, 'admin:restoretransformer', { force = true })
    audit(source, 'restoretransformer', { targetType = normalizedType, targetId = targetId, success = ok ~= false })
    reply(source, ok == false and err or ('transformer/%s restored'):format(targetId), ok == false and 'error' or 'success')
end, false)

-- Admin-only test reset. Clears active repair sessions, transformer damage,
-- parent overrides, and incidents through normal mutation chains.
RegisterCommand('repairall', function(source)
    if not admin(source, 'repairall') then return end

    local cancelledRepairs = RepairManager.CancelAll('admin:repairall')
    local repairedTransformers = 0
    local failures = {}

    for _, transformerId in ipairs(TransformerManager.GetAllIds()) do
        local damageOk, damageErr = TransformerManager.SetDamage(transformerId, 0, 'admin:repairall', {
            cause = Constants.IncidentCause.ADMIN,
            source = source,
            severity = 0,
        })
        local stateOk, stateErr = TransformerManager.SetState(transformerId,
            Constants.TransformerState.ONLINE, 'admin:repairall', { force = true })
        if damageOk ~= false and stateOk ~= false then
            repairedTransformers = repairedTransformers + 1
        else
            failures[#failures + 1] = ('transformer/%s: %s'):format(transformerId, damageErr or stateErr or 'failed')
        end
    end

    local parentTargets = {
        { type = Constants.ComponentType.FEEDER, ids = FeederManager.GetAllIds() },
        { type = Constants.ComponentType.SUBSTATION, ids = SubstationManager.GetAllIds() },
        { type = Constants.ComponentType.GRID, ids = GridManager.GetAllGridIds() },
    }
    for _, group in ipairs(parentTargets) do
        for _, targetId in ipairs(group.ids) do
            local ok, err = FailureManager.Restore(group.type, targetId, 'admin:repairall', source)
            if ok == false then
                failures[#failures + 1] = ('%s/%s: %s'):format(group.type, targetId, err or 'failed')
            end
        end
    end

    local success = #failures == 0
    audit(source, 'repairall', {
        success = success,
        cancelledRepairs = cancelledRepairs,
        repairedTransformers = repairedTransformers,
        failures = #failures > 0 and failures or nil,
    })
    reply(source, success
        and ('all infrastructure repaired: transformers=%d cancelledRepairs=%d'):format(repairedTransformers, cancelledRepairs)
        or ('repairall failed: ' .. table.concat(failures, ' | ')), success and 'success' or 'error')
end, false)

RegisterCommand('createincident', function(source, args)
    if not admin(source, 'createincident') then return end
    local targetType = args[1] and string.lower(args[1]) or nil
    local normalizedType, targetId = explicitTarget(source, targetType, args[2], 'createincident <targetType> <targetId>')
    if not normalizedType then return end

    local incidentId, err = IncidentManager.CreateIncident({
        targetType = normalizedType,
        targetId = targetId,
        cause = Constants.IncidentCause.ADMIN,
        severity = 100,
        startedBy = 'ADMIN:' .. tostring(source),
        metadata = { command = 'createincident' },
    })
    audit(source, 'createincident', { targetType = normalizedType, targetId = targetId, incidentId = incidentId, success = incidentId ~= nil })
    reply(source, incidentId and ('incident created: ' .. incidentId) or err, incidentId and 'success' or 'error')
end, false)

RegisterCommand('resolveincident', function(source, args)
    if not admin(source, 'resolveincident') then return end
    local incidentId = args[1]
    if not Security.ValidateString(incidentId, 'incidentId') then
        reply(source, 'usage: resolveincident <incidentId>', 'error')
        return
    end

    local ok, err = IncidentManager.UpdateStatus(incidentId, Constants.IncidentStatus.RESOLVED, 'ADMIN:' .. tostring(source), {
        command = 'resolveincident',
    })
    audit(source, 'resolveincident', { incidentId = incidentId, success = ok == true })
    reply(source, ok and ('incident resolved: ' .. incidentId) or err, ok and 'success' or 'error')
end, false)

RegisterCommand('reloadtopology', function(source)
    if not admin(source, 'reloadtopology') then return end
    local ok, errors = Validators.ValidateAll()
    if not ok then
        audit(source, 'reloadtopology', { success = false, errors = errors })
        reply(source, 'topology validation failed: ' .. table.concat(errors, ' | '), 'error')
        return
    end

    -- Runtime indexes are rebuilt from already-loaded Lua tables. No file is
    -- loaded here and no SQL schema is touched.
    GridManager.Init()
    Replication.Init()
    audit(source, 'reloadtopology', { success = true })
    reply(source, 'topology indexes rebuilt', 'success')
end, false)

RegisterCommand('resyncvisual', function(source, args)
    if not admin(source, 'resyncvisual') then return end
    local requested = args[1] and string.lower(args[1]) or 'all'
    if requested == 'all' then
        TriggerClientEvent('gnsh-blackout:client:resyncVisual', -1)
        audit(source, 'resyncvisual', { target = 'all', success = true })
        reply(source, 'visual resync sent to all players', 'success')
        return
    end

    local target = tonumber(requested)
    if not target or not Security.ValidateSource(target) then
        audit(source, 'resyncvisual', { target = requested, success = false })
        reply(source, 'unknown player id', 'error')
        return
    end
    TriggerClientEvent('gnsh-blackout:client:resyncVisual', target)
    audit(source, 'resyncvisual', { target = target, success = true })
    reply(source, ('visual resync sent to player %d'):format(target), 'success')
end, false)
