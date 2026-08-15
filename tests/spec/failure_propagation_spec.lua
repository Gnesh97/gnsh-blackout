local originalGrids = Grids
local originalSubstations = Substations
local originalFeeders = Feeders
local originalGridManager = GridManager
local originalPersistence = Persistence
local originalReplication = Replication
local originalLog = Log

Grids = { test_grid = {} }
Substations = { test_sub = { gridId = 'test_grid', transformers = { 'test_tr' } } }
Feeders = { test_feed = { substationId = 'test_sub', transformers = { 'test_tr' }, districts = { 'SANDY' } } }
GridManager = {
    GetGridForSubstation = function(id) return id == 'test_sub' and 'test_grid' or nil end,
    GetSubstationForFeeder = function(id) return id == 'test_feed' and 'test_sub' or nil end,
    GetSubstationForTransformer = function(id) return id == 'test_tr' and 'test_sub' or nil end,
    GetFeederForTransformer = function(id) return id == 'test_tr' and 'test_feed' or nil end,
}
Persistence = nil
Replication = nil
Log = { event = function() end, warn = function() end }

dofile('server/failure_manager.lua')

TEST('feeder override blocks transformer through parent chain', function()
    FailureManager.Restore('grid', 'test_grid', 'unit-reset', 0)
    FailureManager.Restore('feeder', 'test_feed', 'unit-reset', 0)
    local ok = FailureManager.SetState('feeder', 'test_feed', 'OFFLINE', 'unit-test', 0)
    ASSERT_TRUE(ok, 'feeder override should be accepted')
    ASSERT_TRUE(FailureManager.IsBlocked('feeder', 'test_feed'), 'feeder should be blocked')

    local blocker = FailureManager.GetBlockingAncestor('transformer', 'test_tr')
    ASSERT_EQ(blocker.type, 'feeder', 'transformer blocker must be feeder')
    ASSERT_EQ(blocker.id, 'test_feed', 'transformer blocker id must match')
end)

TEST('grid override has priority over feeder override', function()
    FailureManager.Restore('grid', 'test_grid', 'unit-reset', 0)
    FailureManager.Restore('feeder', 'test_feed', 'unit-reset', 0)
    FailureManager.SetState('grid', 'test_grid', 'OFFLINE', 'unit-test', 0)
    FailureManager.SetState('feeder', 'test_feed', 'OFFLINE', 'unit-test', 0)
    local blocker = FailureManager.GetBlockingAncestor('transformer', 'test_tr')
    ASSERT_EQ(blocker.type, 'grid', 'grid must be highest-priority blocker')
    ASSERT_EQ(blocker.id, 'test_grid', 'grid blocker id must match')
end)

TEST('restoring parent reveals remaining child override', function()
    FailureManager.Restore('grid', 'test_grid', 'unit-reset', 0)
    FailureManager.Restore('feeder', 'test_feed', 'unit-reset', 0)
    FailureManager.SetState('grid', 'test_grid', 'OFFLINE', 'unit-test', 0)
    FailureManager.SetState('feeder', 'test_feed', 'OFFLINE', 'unit-test', 0)
    FailureManager.Restore('grid', 'test_grid', 'unit-test', 0)
    local blocker = FailureManager.GetBlockingAncestor('transformer', 'test_tr')
    ASSERT_EQ(blocker.type, 'feeder', 'feeder override must remain after grid restore')

    FailureManager.Restore('feeder', 'test_feed', 'unit-test', 0)
    ASSERT_FALSE(FailureManager.GetBlockingAncestor('transformer', 'test_tr') ~= nil, 'all blockers should be removed')
end)

TEST('unknown parent target is rejected', function()
    FailureManager.Restore('grid', 'test_grid', 'unit-reset', 0)
    FailureManager.Restore('feeder', 'test_feed', 'unit-reset', 0)
    local ok = FailureManager.SetState('feeder', 'missing', 'OFFLINE', 'unit-test', 0)
    ASSERT_FALSE(ok, 'unknown feeder must be rejected')
end)

TEST('region override blocks unassigned districts without topology', function()
    local region = PowerRegions.Get('towns')
    local district = 'GRAPES'

    FailureManager.Restore('region', region.id, 'unit-reset', 0)
    local ok = FailureManager.SetState('region', region.id, 'OFFLINE', 'unit-test', 0)
    ASSERT_TRUE(ok, 'region override should be accepted without feeder assignments')

    local blocker = FailureManager.GetBlockingAncestor('district', district)
    ASSERT_EQ(blocker.type, 'region', 'unassigned district must be blocked by region')
    ASSERT_EQ(blocker.id, region.id, 'region blocker id must match')

    FailureManager.Restore('region', region.id, 'unit-test', 0)
end)

Grids = originalGrids
Substations = originalSubstations
Feeders = originalFeeders
GridManager = originalGridManager
Persistence = originalPersistence
Replication = originalReplication
Log = originalLog
