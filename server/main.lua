-- Server startup orchestration and late database restore.

local started = false
local bootDatabase
local lateRestoreDone = false

InfrastructureBootOrder = {
    'persistence', 'topology_runtime', 'transformer_restore',
    'override_restore', 'incident_restore', 'grid_calculation',
    'district_replication', 'random_failure_scheduler',
}

local function restore(persisted)
    for _, row in ipairs(persisted.transformers or {}) do TransformerManager.RestoreState(row) end
    FailureManager.RestoreAll(persisted.overrides or {})

    IncidentManager.Init()
    IncidentManager.SetCounterAtLeast(persisted.incidentCounter or 0)
    for _, incident in ipairs(persisted.incidents or {}) do IncidentManager.RestoreIncident(incident) end
end

local function boot()
    local ok, errors, warnings = Validators.ValidateAll()
    if not ok then
        Log.error(('config validation FAILED with %d error(s) - refusing to start'):format(#errors))
        for _, err in ipairs(errors) do Log.error('  - ' .. err) end
        Log.event(Constants.LogEvent.CONFIG_INVALID, { errorCount = #errors })
        return false
    end

    for _, warning in ipairs(warnings or {}) do Log.warn('[Infrastructure] WARNING: ' .. warning) end
    Log.event(Constants.LogEvent.CONFIG_OK)

    GridManager.Init()
    TransformerManager.Init()

    local persisted = Persistence and Persistence.LoadAll() or {
        transformers = {}, incidents = {}, overrides = {}, incidentCounter = 0,
    }
    restore(persisted)
    Replication.Init()
    RandomFailureManager.Start()

    local info = Bridge and Bridge.GetAdapterSnapshot and Bridge.GetAdapterSnapshot() or {}
    bootDatabase = info.database
    started = true
    return true
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    boot()
end)

if GetResourceState(GetCurrentResourceName()) == 'started' and not started then boot() end

-- If oxmysql starts after gnsh-blackout, bridge loader switches to it and
-- this handler restores persisted state without requiring a resource restart.
AddEventHandler('gnsh-blackout:server:bridgeChanged', function(info)
    if not started or not info then return end
    if info.database ~= 'oxmysql' then
        lateRestoreDone = false
        return
    end
    if lateRestoreDone or bootDatabase == 'oxmysql' then return end
    lateRestoreDone = true
    local persisted = Persistence.LoadAll()
    restore(persisted)
    Replication.Init()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if RepairManager and RepairManager.CancelAll then RepairManager.CancelAll('resource_stop') end
    RandomFailureManager.Stop()
    Log.event(Constants.LogEvent.RESOURCE_STOPPED)
end)

RegisterCommand('infrastatus', function(source)
    if source ~= 0 then return end
    print(('[gnsh-blackout] started=%s grids=%d'):format(tostring(started), #GridManager.GetAllGridIds()))
end, false)
