--[[
    server/main.lua

    Server startup orchestration (spec §47):
        Load Static Configuration  -> already done (shared_scripts)
        Build Runtime Cache        -> GridManager.Init(), TransformerManager.Init()
        Recalculate Grids          -> Replication.Init()
        Publish Replicated State   -> (part of Replication.Init())
        Start Scheduler            -> Phase 25 RandomFailureManager

    Everything is gated on Validators.ValidateAll() (spec RULE 7, plan
    Phase 1 acceptance criterion): a broken config logs every error and
    the resource refuses to build a runtime cache or publish any state at
    all, rather than half-starting with a grid that's silently wrong.
]]

local started = false

InfrastructureBootOrder = {
    'persistence', 'topology_runtime', 'transformer_restore',
    'override_restore', 'incident_restore', 'grid_calculation',
    'district_replication', 'random_failure_scheduler',
}

local function boot()
    local ok, errors, warnings = Validators.ValidateAll()
    if not ok then
        Log.error(('config validation FAILED with %d error(s) — refusing to start'):format(#errors))
        for _, err in ipairs(errors) do
            Log.error('  - ' .. err)
        end
        Log.event(Constants.LogEvent.CONFIG_INVALID, { errorCount = #errors })
        return false
    end

    -- Non-fatal registry/topology findings (Phase 17, Config.Topology.strict
    -- = false path) — printed so gaps are visible without blocking startup,
    -- same "warn but don't crash" spirit as shared/districts.lua's AABB note.
    for _, warn in ipairs(warnings or {}) do
        Log.warn('[Infrastructure] WARNING: ' .. warn)
    end

    Log.event(Constants.LogEvent.CONFIG_OK)

    GridManager.Init()
    TransformerManager.Init()

    -- spec §47 boot order: Restore Transformer States -> Restore Active
    -- Incidents -> Recalculate Grids (Replication.Init(), below, reads
    -- TransformerManager's now-restored state live). No-op / empty
    -- tables if oxmysql isn't running OR server/persistence.lua somehow
    -- isn't loaded — Phase 1-13's memory-only behavior otherwise,
    -- unchanged (matches persistence.lua's own soft-dependency design;
    -- a hard `Persistence.LoadAll()` call here without this guard would
    -- crash boot() entirely and skip Replication.Init(), which is
    -- exactly the bug live testing caught, 2026-08-08).
    local persisted = Persistence and Persistence.LoadAll() or {
        transformers = {}, incidents = {}, overrides = {}, incidentCounter = 0,
    }

    for _, row in ipairs(persisted.transformers) do
        TransformerManager.RestoreState(row)
    end

    FailureManager.RestoreAll(persisted.overrides)

    IncidentManager.Init()
    IncidentManager.SetCounterAtLeast(persisted.incidentCounter)

    for _, incident in ipairs(persisted.incidents) do
        IncidentManager.RestoreIncident(incident)
    end

    Replication.Init()
    RandomFailureManager.Start()

    started = true
    return true
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    boot()
end)

-- Handles the case where this script is evaluated after the resource is
-- already "started" from the game's perspective (e.g. a script reload
-- rather than a full resource restart) — onResourceStart won't fire again
-- in that case, so boot immediately if we're not already initialized.
if GetResourceState(GetCurrentResourceName()) == 'started' and not started then
    boot()
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if RepairManager and RepairManager.CancelAll then
        RepairManager.CancelAll('resource_stop')
    end
    RandomFailureManager.Stop()
    Log.event(Constants.LogEvent.RESOURCE_STOPPED)
end)

RegisterCommand('infrastatus', function(source)
    if source ~= 0 then return end -- console-only, matches other read-only debug commands' spirit
    print(('[gnsh-blackout] started=%s grids=%d'):format(tostring(started), #GridManager.GetAllGridIds()))
end, false)
