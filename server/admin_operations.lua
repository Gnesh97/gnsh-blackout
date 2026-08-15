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

for _, region in ipairs(PowerRegions.GetAll()) do
    AdminOperations.CommandNames[#AdminOperations.CommandNames + 1] = 'blackout_' .. region.id
    AdminOperations.CommandNames[#AdminOperations.CommandNames + 1] = 'restore_' .. region.id
end

local commandHandlers = {}

local function registerAdminCommand(name, handler)
    commandHandlers[name] = handler
    RegisterCommand(name, handler, false)
end

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

registerAdminCommand('setgridstate', function(source, args)
    setState(source, args, Constants.ComponentType.GRID, 'setgridstate <gridId> <ONLINE|OFFLINE>')
end, false)

registerAdminCommand('setsubstationstate', function(source, args)
    setState(source, args, Constants.ComponentType.SUBSTATION, 'setsubstationstate <substationId> <ONLINE|OFFLINE>')
end, false)

registerAdminCommand('setfeederstate', function(source, args)
    setState(source, args, Constants.ComponentType.FEEDER, 'setfeederstate <feederId> <ONLINE|OFFLINE>')
end, false)

registerAdminCommand('restoregrid', function(source, args)
    restore(source, args, Constants.ComponentType.GRID, 'restoregrid', 'restoregrid <gridId>')
end, false)

registerAdminCommand('restoresubstation', function(source, args)
    restore(source, args, Constants.ComponentType.SUBSTATION, 'restoresubstation', 'restoresubstation <substationId>')
end, false)

registerAdminCommand('restorefeeder', function(source, args)
    restore(source, args, Constants.ComponentType.FEEDER, 'restorefeeder', 'restorefeeder <feederId>')
end, false)

registerAdminCommand('restoretransformer', function(source, args)
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
registerAdminCommand('repairall', function(source)
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
        { type = Constants.ComponentType.REGION, ids = (function()
            local ids = {}
            for _, region in ipairs(PowerRegions.GetAll()) do ids[#ids + 1] = region.id end
            return ids
        end)() },
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

registerAdminCommand('createincident', function(source, args)
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

registerAdminCommand('resolveincident', function(source, args)
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

registerAdminCommand('reloadtopology', function(source)
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

registerAdminCommand('resyncvisual', function(source, args)
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

local function applyRegionState(source, regionId, state, command)
    if not admin(source, command) then return false end

    local region = PowerRegions.Get(regionId)
    if not region then
        reply(source, 'Bilinmeyen bölgesel kesinti grubu.', 'error')
        return false
    end

    local ok, err = FailureManager.SetState(
        Constants.ComponentType.REGION,
        regionId,
        state,
        'admin:' .. command,
        source,
        {
            cause = Constants.IncidentCause.ADMIN,
            severity = state == Constants.ComponentState.OFFLINE and 100 or 0,
        }
    )
    audit(source, command, {
        targetType = Constants.ComponentType.REGION,
        targetId = regionId,
        districtCount = #region.districts,
        state = state,
        success = ok == true,
    })

    local action = state == Constants.ComponentState.OFFLINE and 'kesildi' or 'geri verildi'
    reply(source, ok
        and ('%s elektriği %s (%d bölge)'):format(region.label, action, #region.districts)
        or err, ok and 'success' or 'error')
    return ok == true
end

for _, region in ipairs(PowerRegions.GetAll()) do
    local regionId = region.id
    local blackoutCommand = 'blackout_' .. regionId
    local restoreCommand = 'restore_' .. regionId

    registerAdminCommand(blackoutCommand, function(source)
        return applyRegionState(source, regionId, Constants.ComponentState.OFFLINE, blackoutCommand)
    end, false)

    registerAdminCommand(restoreCommand, function(source)
        return applyRegionState(source, regionId, Constants.ComponentState.ONLINE, restoreCommand)
    end, false)
end

AdminOperations.CommandCatalog = {
    {
        command = 'setgridstate',
        label = 'Şebeke durumunu değiştir',
        description = 'Bir gridin enerji durumunu çevrimiçi veya çevrimdışı yapar.',
        usage = 'setgridstate <gridId> <ONLINE|OFFLINE>',
        args = {
            { key = 'gridId', label = 'Grid kimliği', placeholder = 'blaine_south' },
            { key = 'state', label = 'Durum', placeholder = 'ONLINE veya OFFLINE' },
        },
    },
    {
        command = 'setsubstationstate',
        label = 'Trafo merkezi durumunu değiştir',
        description = 'Seçilen trafo merkezinin enerji durumunu değiştirir.',
        usage = 'setsubstationstate <substationId> <ONLINE|OFFLINE>',
        args = {
            { key = 'substationId', label = 'Merkez kimliği', placeholder = 'sandy_substation_01' },
            { key = 'state', label = 'Durum', placeholder = 'ONLINE veya OFFLINE' },
        },
    },
    {
        command = 'setfeederstate',
        label = 'Besleyici durumunu değiştir',
        description = 'Bir enerji besleyicisini devreye alır veya devre dışı bırakır.',
        usage = 'setfeederstate <feederId> <ONLINE|OFFLINE>',
        args = {
            { key = 'feederId', label = 'Besleyici kimliği', placeholder = 'blaine_south_feed_a' },
            { key = 'state', label = 'Durum', placeholder = 'ONLINE veya OFFLINE' },
        },
    },
    {
        command = 'restoregrid',
        label = 'Gridi geri yükle',
        description = 'Grid üzerindeki yönetici kaynaklı kesintiyi kaldırır.',
        usage = 'restoregrid <gridId>',
        args = { { key = 'gridId', label = 'Grid kimliği', placeholder = 'blaine_south' } },
    },
    {
        command = 'restoresubstation',
        label = 'Trafo merkezini geri yükle',
        description = 'Trafo merkezini normal çalışma durumuna döndürür.',
        usage = 'restoresubstation <substationId>',
        args = { { key = 'substationId', label = 'Merkez kimliği', placeholder = 'sandy_substation_01' } },
    },
    {
        command = 'restorefeeder',
        label = 'Besleyiciyi geri yükle',
        description = 'Besleyici üzerindeki yönetici kesintisini kaldırır.',
        usage = 'restorefeeder <feederId>',
        args = { { key = 'feederId', label = 'Besleyici kimliği', placeholder = 'blaine_south_feed_a' } },
    },
    {
        command = 'restoretransformer',
        label = 'Trafoyu geri yükle',
        description = 'Hasarı sıfırlar ve seçilen trafonun enerjisini geri verir.',
        usage = 'restoretransformer <transformerId>',
        args = { { key = 'transformerId', label = 'Trafo kimliği', placeholder = 'sandy_tr_01' } },
    },
    {
        command = 'createincident',
        label = 'Olay oluştur',
        description = 'Seçilen altyapı hedefi için yönetici kaynaklı olay açar.',
        usage = 'createincident <targetType> <targetId>',
        args = {
            { key = 'targetType', label = 'Hedef türü', placeholder = 'grid / substation / feeder / transformer' },
            { key = 'targetId', label = 'Hedef kimliği', placeholder = 'sandy_tr_01' },
        },
    },
    {
        command = 'resolveincident',
        label = 'Olayı çözüldü işaretle',
        description = 'Aktif bir olayı yönetici kararıyla çözüldü durumuna geçirir.',
        usage = 'resolveincident <incidentId>',
        args = { { key = 'incidentId', label = 'Olay kimliği', placeholder = 'INC-0001' } },
    },
    {
        command = 'reloadtopology',
        label = 'Topolojiyi yeniden yükle',
        description = 'Yüklü grid, feeder ve district indekslerini doğrular ve yeniler.',
        usage = 'reloadtopology',
        args = {},
    },
    {
        command = 'resyncvisual',
        label = 'Görsel durumu eşitle',
        description = 'Blackout görsel durumunu tüm oyunculara veya tek bir oyuncuya yeniden gönderir.',
        usage = 'resyncvisual [all|playerId]',
        args = { { key = 'target', label = 'Hedef', placeholder = 'all veya oyuncu ID' } },
    },
    {
        command = 'repairall',
        label = 'Tüm altyapıyı onar',
        description = 'Tüm trafoları ve üst seviye altyapı override’larını normal duruma döndürür.',
        usage = 'repairall',
        args = {},
    },
}

local function copyCommandCatalog()
    local result = {}
    for index, definition in ipairs(AdminOperations.CommandCatalog) do
        local copy = {
            command = definition.command,
            label = definition.label,
            description = definition.description,
            usage = definition.usage,
            args = {},
        }
        for argIndex, argument in ipairs(definition.args or {}) do
            copy.args[argIndex] = {
                key = argument.key,
                label = argument.label,
                placeholder = argument.placeholder,
            }
        end
        result[index] = copy
    end
    return result
end

local function copyRegionCatalog()
    local result = {}
    for _, region in ipairs(PowerRegions.GetAll()) do
        result[#result + 1] = {
            id = region.id,
            label = region.label,
            description = region.description,
            districtCount = #region.districts,
            blackoutCommand = 'blackout_' .. region.id,
            restoreCommand = 'restore_' .. region.id,
            active = FailureManager.IsBlocked(Constants.ComponentType.REGION, region.id),
        }
    end
    return result
end

local function snapshotDistricts()
    local result = {}
    for code, entry in pairs(Districts.ByCode or {}) do
        if entry.enabled ~= false and entry.aabb and entry.aabb.min and entry.aabb.max then
            local state = Replication.GetDistrictState(code) or {
                powered = true,
                level = 1.0,
                status = Constants.GridStatus.ONLINE,
                revision = 0,
            }
            result[#result + 1] = {
                id = code,
                label = entry.label,
                category = entry.category,
                assignment = Districts.GetAssignment(code),
                grid = entry.defaultGrid,
                bounds = {
                    minX = tonumber(entry.aabb.min.x) or 0,
                    minY = tonumber(entry.aabb.min.y) or 0,
                    maxX = tonumber(entry.aabb.max.x) or 0,
                    maxY = tonumber(entry.aabb.max.y) or 0,
                },
                state = {
                    powered = state.powered ~= false,
                    level = tonumber(state.level) or 1.0,
                    status = state.status or Constants.GridStatus.ONLINE,
                    revision = tonumber(state.revision) or 0,
                },
            }
        end
    end
    table.sort(result, function(a, b) return a.id < b.id end)
    return result
end

function AdminOperations.GetAdminSnapshot()
    return {
        title = 'Yönetici Kontrol Merkezi',
        subtitle = 'Şehir altyapısı için canlı yönetim yüzeyi',
        districts = snapshotDistricts(),
        commands = copyCommandCatalog(),
        regions = copyRegionCatalog(),
    }
end

local function normalizeAdminArgs(args)
    if type(args) ~= 'table' then return {} end
    local result = {}
    for index = 1, math.min(#args, 8) do
        local value = args[index]
        if type(value) ~= 'string' or #value > 96 then return nil end
        result[index] = value
    end
    return result
end

function AdminOperations.Execute(source, command, args)
    local name = type(command) == 'string' and string.lower(command) or ''
    local handler = commandHandlers[name]
    if not handler then
        reply(source, 'Bilinmeyen yönetici komutu.', 'error')
        return false
    end
    if not admin(source, 'nui:' .. name) then return false end

    local normalizedArgs = normalizeAdminArgs(args)
    if not normalizedArgs then
        reply(source, 'Komut parametreleri geçersiz.', 'error')
        return false
    end

    local ok, result = pcall(handler, source, normalizedArgs)
    if not ok then
        Log.error(('admin NUI command failed: %s: %s'):format(name, tostring(result)))
        reply(source, 'Komut çalıştırılırken bir hata oluştu.', 'error')
        return false
    end
    return result ~= false
end

RegisterNetEvent('gnsh-blackout:server:requestAdminPanel', function()
    local sourceId = source
    if not admin(sourceId, 'openadminpanel') then return end
    TriggerClientEvent('gnsh-blackout:client:adminOpen', sourceId, AdminOperations.GetAdminSnapshot())
end)

RegisterNetEvent('gnsh-blackout:server:requestAdminSnapshot', function()
    local sourceId = source
    if not admin(sourceId, 'refreshadminpanel') then return end
    TriggerClientEvent('gnsh-blackout:client:adminData', sourceId, AdminOperations.GetAdminSnapshot())
end)

RegisterNetEvent('gnsh-blackout:server:adminCommand', function(command, args)
    local sourceId = source
    if not AdminOperations.Execute(sourceId, command, args) then return end
    TriggerClientEvent('gnsh-blackout:client:adminData', sourceId, AdminOperations.GetAdminSnapshot())
end)
