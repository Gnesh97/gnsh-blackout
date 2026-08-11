--[[
    tests/spec/topology_spec.lua

    Phase 18 (Citywide Power Topology + Feeder Layer). Two things are
    genuinely testable under a plain Lua interpreter here:

    1. PowerCalculator.CalculateDistrict — pure function, same testability
       class as tests/spec/power_policy_spec.lua's PowerCalculator.Calculate
       coverage. Takes a plain array of pre-computed feeder states, no
       FiveM natives, no GridManager/Replication dependency.

       2. shared/feeders.lua's static shape — Feeders touches zero natives.
       server/feeder_manager.lua, server/grid_manager.lua's
       feeder indices, and server/replication.lua's district aggregation
       all need Log/TransformerManager/GridManager and are NOT exercised
       here — verify those in-game via /showfeeders, /powerpath,
       /topologyaudit per README.md's debug quick start instead.
]]

local ONLINE_STATE = { powered = true, level = 1.0, status = Constants.GridStatus.ONLINE }
local DEGRADED_STATE = { powered = true, level = Config.DegradedLevel, status = Constants.GridStatus.DEGRADED }
local OFFLINE_STATE = { powered = false, level = 0.0, status = Constants.GridStatus.BLACKOUT }

TEST('CalculateDistrict: no supplying feeders -> blackout', function()
    local result = PowerCalculator.CalculateDistrict({})
    ASSERT_FALSE(result.powered)
    ASSERT_EQ(result.level, 0.0)
    ASSERT_EQ(result.status, Constants.GridStatus.BLACKOUT)
end)

TEST('CalculateDistrict: single online feeder -> full power', function()
    local result = PowerCalculator.CalculateDistrict({ ONLINE_STATE })
    ASSERT_TRUE(result.powered)
    ASSERT_EQ(result.level, 1.0)
    ASSERT_EQ(result.status, Constants.GridStatus.ONLINE)
end)

TEST('CalculateDistrict: single degraded feeder -> degraded power', function()
    local result = PowerCalculator.CalculateDistrict({ DEGRADED_STATE })
    ASSERT_TRUE(result.powered)
    ASSERT_EQ(result.level, Config.DegradedLevel)
    ASSERT_EQ(result.status, Constants.GridStatus.DEGRADED)
end)

TEST('CalculateDistrict: all supplying feeders offline -> blackout', function()
    local result = PowerCalculator.CalculateDistrict({ OFFLINE_STATE, OFFLINE_STATE })
    ASSERT_FALSE(result.powered)
    ASSERT_EQ(result.level, 0.0)
    ASSERT_EQ(result.status, Constants.GridStatus.BLACKOUT)
end)

TEST('CalculateDistrict: ANY policy — one online feeder outweighs one offline feeder', function()
    local result = PowerCalculator.CalculateDistrict({ OFFLINE_STATE, ONLINE_STATE })
    ASSERT_TRUE(result.powered)
    ASSERT_EQ(result.level, 1.0)
    ASSERT_EQ(result.status, Constants.GridStatus.ONLINE)

    -- spec §29.1 partial recovery example, "Feeder A ONLINE, Feeder B
    -- OFFLINE" — order must not matter (both permutations tested).
    local reversed = PowerCalculator.CalculateDistrict({ ONLINE_STATE, OFFLINE_STATE })
    ASSERT_TRUE(reversed.powered)
end)

TEST('CalculateDistrict: online feeder beats a degraded one for the reported level', function()
    local result = PowerCalculator.CalculateDistrict({ DEGRADED_STATE, ONLINE_STATE })
    ASSERT_EQ(result.level, 1.0)
    ASSERT_EQ(result.status, Constants.GridStatus.ONLINE)
end)

TEST('CalculateDistrict: only a degraded feeder online -> reports the degraded level, not 1.0', function()
    local result = PowerCalculator.CalculateDistrict({ OFFLINE_STATE, DEGRADED_STATE })
    ASSERT_TRUE(result.powered)
    ASSERT_EQ(result.level, Config.DegradedLevel)
    ASSERT_EQ(result.status, Constants.GridStatus.DEGRADED)
end)

TEST('every feeder in shared/feeders.lua has the expected shape', function()
    for feederId, feeder in pairs(Feeders) do
        ASSERT_TRUE(feeder.substationId ~= nil, feederId .. ': missing substationId')
        ASSERT_TRUE(type(feeder.transformers) == 'table' and #feeder.transformers > 0, feederId .. ': missing transformers')
        ASSERT_TRUE(type(feeder.districts) == 'table' and #feeder.districts > 0, feederId .. ': missing districts')
        ASSERT_TRUE(feeder.powerPolicy ~= nil and feeder.powerPolicy.mode ~= nil, feederId .. ': missing powerPolicy.mode')
    end
end)

TEST('shared/feeders.lua: two feeders on the same substation prove the multi-feeder-per-substation shape (spec §18.7)', function()
    local a = Feeders['blaine_south_feed_a']
    local b = Feeders['blaine_south_feed_b']
    ASSERT_TRUE(a ~= nil and b ~= nil, 'expected blaine_south_feed_a and blaine_south_feed_b to exist')
    ASSERT_EQ(a.substationId, b.substationId)
    ASSERT_TRUE(a.transformers[1] ~= b.transformers[1], 'the two feeders must not share a transformer')
end)
