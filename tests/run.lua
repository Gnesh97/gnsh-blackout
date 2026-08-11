--[[
    tests/run.lua

    Framework-free test harness. Run from the resource root with a plain
    Lua 5.4 interpreter:

        lua5.4 tests/run.lua

    WHAT'S TESTABLE THIS WAY, AND WHY NOT EVERYTHING:
    Most of shared/*.lua and server/power_calculator.lua touch no FiveM
    natives at all, so they load and run identically under stock Lua.
    The one native they DO need is `vector3(x, y, z)` (used by
    shared/districts.lua for AABB corners) — shimmed below as a plain
    {x=,y=,z=} table, which is all Utils.PointInAABB/AABBVolume actually
    need.

    shared/grids.lua and shared/world_placement.lua are now plain Lua and
    load safely with the vector3 shim. validators_spec.lua still tests
    shared/validators.lua against small synthetic fixtures so validator
    behavior remains isolated from production topology changes.

    Modules needing Log/GridManager/Replication (server/transformer_
    manager.lua, server/replication.lua, the bridge/* adapters) are not
    exercised here — verify those in-game via /setgridpower, /setdamage,
    /griddebug per README.md's debug quick start instead.
]]

local passed, failed = 0, 0

function TEST(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print(('  [PASS] %s'):format(name))
    else
        failed = failed + 1
        print(('  [FAIL] %s -- %s'):format(name, tostring(err)))
    end
end

function ASSERT_EQ(actual, expected, msg)
    if actual ~= expected then
        error(('%s (expected %s, got %s)'):format(msg or 'values differ', tostring(expected), tostring(actual)), 2)
    end
end

function ASSERT_TRUE(value, msg)
    if not value then
        error(msg or 'expected truthy value', 2)
    end
end

function ASSERT_FALSE(value, msg)
    if value then
        error(msg or 'expected falsy value', 2)
    end
end

-- Minimal FiveM native shim — see header comment.
function vector3(x, y, z)
    return { x = x, y = y, z = z }
end

-- Load order mirrors fxmanifest.lua's shared_scripts.
dofile('config.lua')
dofile('shared/utilities.lua')
dofile('shared/constants.lua')
dofile('shared/types.lua')
dofile('shared/districts.lua')
dofile('shared/grids.lua')
dofile('shared/feeders.lua')
dofile('shared/world_placement.lua')
dofile('shared/zone_resolver.lua')
dofile('profiles/sandy.lua')
dofile('profiles/ls_central.lua')
dofile('shared/visual_profile_resolver.lua')
dofile('shared/validators.lua')
dofile('server/power_calculator.lua')
dofile('server/api_helpers.lua')
dofile('client/visual/ownership.lua') -- touches zero natives, see tests/spec/visual_ownership_spec.lua header

-- Phase 23 impact tests use the real static topology and reverse indexes.
-- Runtime incident lifecycle remains an in-game/server integration concern.
Log = { event = function() end, warn = function() end, error = function() end }
dofile('server/persistence.lua')
dofile('server/metrics.lua')
dofile('server/grid_manager.lua')
GridManager.Init()
dofile('server/security_manager.lua')
dofile('server/incident_impact.lua')
dofile('server/random_failure_manager.lua')
local realRegisterCommand = RegisterCommand
RegisterCommand = function() end
dofile('server/admin_operations.lua')
RegisterCommand = realRegisterCommand
local realAddEventHandler = AddEventHandler
local realGetResourceState = GetResourceState
local realGetCurrentResourceName = GetCurrentResourceName
AddEventHandler = function() end
GetResourceState = function() return 'stopped' end
GetCurrentResourceName = function() return 'gnsh-blackout' end
RegisterCommand = function() end
dofile('server/main.lua')
AddEventHandler = realAddEventHandler
GetResourceState = realGetResourceState
GetCurrentResourceName = realGetCurrentResourceName
RegisterCommand = realRegisterCommand

print('gnsh-blackout — pure Lua unit tests')
print('')

print('damage_model_spec.lua')
dofile('tests/spec/damage_model_spec.lua')

print('power_policy_spec.lua')
dofile('tests/spec/power_policy_spec.lua')

print('validators_spec.lua')
dofile('tests/spec/validators_spec.lua')

print('config_defaults_spec.lua')
dofile('tests/spec/config_defaults_spec.lua')

print('visual_profile_spec.lua')
dofile('tests/spec/visual_profile_spec.lua')

print('zone_resolver_spec.lua')
dofile('tests/spec/zone_resolver_spec.lua')

print('visual_ownership_spec.lua')
dofile('tests/spec/visual_ownership_spec.lua')

print('world_placement_spec.lua')
dofile('tests/spec/world_placement_spec.lua')

print('district_registry_spec.lua')
dofile('tests/spec/district_registry_spec.lua')

print('topology_spec.lua')
dofile('tests/spec/topology_spec.lua')

print('district_controller_spec.lua')
dofile('tests/spec/district_controller_spec.lua')

print('failure_propagation_spec.lua')
dofile('tests/spec/failure_propagation_spec.lua')

print('recovery_spec.lua')
dofile('tests/spec/recovery_spec.lua')

print('incident_impact_spec.lua')
dofile('tests/spec/incident_impact_spec.lua')

print('api_spec.lua')
dofile('tests/spec/api_spec.lua')

print('random_failure_spec.lua')
dofile('tests/spec/random_failure_spec.lua')

print('metrics_spec.lua')
dofile('tests/spec/metrics_spec.lua')

print('security_spec.lua')
dofile('tests/spec/security_spec.lua')

print('admin_operations_spec.lua')
dofile('tests/spec/admin_operations_spec.lua')

print('restart_resync_spec.lua')
dofile('tests/spec/restart_resync_spec.lua')

print('integration_contract_spec.lua')
dofile('tests/spec/integration_contract_spec.lua')

print('')
print(('%d passed, %d failed'):format(passed, failed))

if failed > 0 then
    os.exit(1)
end
