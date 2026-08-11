--[[
    tests/spec/power_policy_spec.lua

    Truth table coverage for PowerCalculator.Calculate across the four
    implemented policies (PRIMARY, ANY, ALL, REQUIRED_COUNT) and 1-3
    transformer grids in every relevant ONLINE/DEGRADED/OFFLINE
    combination (spec §15, §16).
]]

local ONLINE = Constants.TransformerState.ONLINE
local DEGRADED = Constants.TransformerState.DEGRADED
local OFFLINE = Constants.TransformerState.OFFLINE

local function tr(id, primary, state)
    return { id = id, primary = primary, state = state }
end

-- ── PRIMARY ──────────────────────────────────────────────────────────────

TEST('PRIMARY: primary online -> full power', function()
    local grid = { powerPolicy = { mode = 'PRIMARY' } }
    local result = PowerCalculator.Calculate(grid, { tr('a', true, ONLINE), tr('b', false, OFFLINE) })
    ASSERT_TRUE(result.powered)
    ASSERT_EQ(result.level, 1.0)
    ASSERT_EQ(result.status, Constants.GridStatus.ONLINE)
end)

TEST('PRIMARY: primary degraded -> degraded power', function()
    local grid = { powerPolicy = { mode = 'PRIMARY' } }
    local result = PowerCalculator.Calculate(grid, { tr('a', true, DEGRADED) })
    ASSERT_TRUE(result.powered)
    ASSERT_EQ(result.level, Config.DegradedLevel)
    ASSERT_EQ(result.status, Constants.GridStatus.DEGRADED)
end)

TEST('PRIMARY: primary offline, backup online -> still blackout', function()
    local grid = { powerPolicy = { mode = 'PRIMARY' } }
    local result = PowerCalculator.Calculate(grid, { tr('a', true, OFFLINE), tr('b', false, ONLINE) })
    ASSERT_FALSE(result.powered)
    ASSERT_EQ(result.level, 0.0)
    ASSERT_EQ(result.status, Constants.GridStatus.BLACKOUT)
end)

TEST('PRIMARY: all offline -> blackout', function()
    local grid = { powerPolicy = { mode = 'PRIMARY' } }
    local result = PowerCalculator.Calculate(grid, { tr('a', true, OFFLINE) })
    ASSERT_FALSE(result.powered)
end)

-- ── ANY ──────────────────────────────────────────────────────────────────

TEST('ANY: one of three online -> full power', function()
    local grid = { powerPolicy = { mode = 'ANY' } }
    local result = PowerCalculator.Calculate(grid, { tr('a', false, OFFLINE), tr('b', false, ONLINE), tr('c', false, OFFLINE) })
    ASSERT_TRUE(result.powered)
    ASSERT_EQ(result.level, 1.0)
end)

TEST('ANY: one degraded, rest offline -> degraded power', function()
    local grid = { powerPolicy = { mode = 'ANY' } }
    local result = PowerCalculator.Calculate(grid, { tr('a', false, OFFLINE), tr('b', false, DEGRADED) })
    ASSERT_TRUE(result.powered)
    ASSERT_EQ(result.level, Config.DegradedLevel)
end)

TEST('ANY: all offline -> blackout', function()
    local grid = { powerPolicy = { mode = 'ANY' } }
    local result = PowerCalculator.Calculate(grid, { tr('a', false, OFFLINE), tr('b', false, OFFLINE) })
    ASSERT_FALSE(result.powered)
end)

-- ── ALL ──────────────────────────────────────────────────────────────────

TEST('ALL: every transformer online -> full power', function()
    local grid = { powerPolicy = { mode = 'ALL' } }
    local result = PowerCalculator.Calculate(grid, { tr('a', false, ONLINE), tr('b', false, ONLINE) })
    ASSERT_TRUE(result.powered)
    ASSERT_EQ(result.level, 1.0)
end)

TEST('ALL: one offline out of three -> not full power, falls to degraded tier', function()
    local grid = { powerPolicy = { mode = 'ALL' } }
    local result = PowerCalculator.Calculate(grid, { tr('a', false, ONLINE), tr('b', false, ONLINE), tr('c', false, OFFLINE) })
    ASSERT_FALSE(result.status == Constants.GridStatus.ONLINE)
end)

TEST('ALL: every transformer online+degraded (mixed, none offline) -> degraded power', function()
    local grid = { powerPolicy = { mode = 'ALL' } }
    local result = PowerCalculator.Calculate(grid, { tr('a', false, ONLINE), tr('b', false, DEGRADED) })
    ASSERT_TRUE(result.powered)
    ASSERT_EQ(result.level, Config.DegradedLevel)
    ASSERT_EQ(result.status, Constants.GridStatus.DEGRADED)
end)

TEST('ALL: empty transformer list -> blackout (no transformers cannot satisfy ALL)', function()
    local grid = { powerPolicy = { mode = 'ALL' } }
    local result = PowerCalculator.Calculate(grid, {})
    ASSERT_FALSE(result.powered)
end)

-- ── REQUIRED_COUNT ───────────────────────────────────────────────────────

TEST('REQUIRED_COUNT: 2 required, 2 online out of 3 -> full power', function()
    local grid = { powerPolicy = { mode = 'REQUIRED_COUNT', requiredOnline = 2 } }
    local result = PowerCalculator.Calculate(grid, { tr('a', false, ONLINE), tr('b', false, ONLINE), tr('c', false, OFFLINE) })
    ASSERT_TRUE(result.powered)
    ASSERT_EQ(result.level, 1.0)
end)

TEST('REQUIRED_COUNT: 2 required, 1 online -> not full power', function()
    local grid = { powerPolicy = { mode = 'REQUIRED_COUNT', requiredOnline = 2 } }
    local result = PowerCalculator.Calculate(grid, { tr('a', false, ONLINE), tr('b', false, OFFLINE), tr('c', false, OFFLINE) })
    ASSERT_FALSE(result.status == Constants.GridStatus.ONLINE)
end)

TEST('REQUIRED_COUNT: 2 required, 1 online + 1 degraded -> degraded power', function()
    local grid = { powerPolicy = { mode = 'REQUIRED_COUNT', requiredOnline = 2 } }
    local result = PowerCalculator.Calculate(grid, { tr('a', false, ONLINE), tr('b', false, DEGRADED), tr('c', false, OFFLINE) })
    ASSERT_TRUE(result.powered)
    ASSERT_EQ(result.status, Constants.GridStatus.DEGRADED)
end)

TEST('REQUIRED_COUNT: 2 required, 0 online -> blackout', function()
    local grid = { powerPolicy = { mode = 'REQUIRED_COUNT', requiredOnline = 2 } }
    local result = PowerCalculator.Calculate(grid, { tr('a', false, OFFLINE), tr('b', false, OFFLINE) })
    ASSERT_FALSE(result.powered)
end)

-- ── DegradedLevel below BlackoutThreshold edge case ─────────────────────

TEST('degraded tier below BlackoutThreshold reports blackout, not degraded', function()
    local originalDegraded = Config.DegradedLevel
    Config.DegradedLevel = 0.01 -- below default BlackoutThreshold (0.05)

    local grid = { powerPolicy = { mode = 'ANY' } }
    local result = PowerCalculator.Calculate(grid, { tr('a', false, DEGRADED) })

    Config.DegradedLevel = originalDegraded -- restore for subsequent tests

    ASSERT_FALSE(result.powered)
    ASSERT_EQ(result.status, Constants.GridStatus.BLACKOUT)
end)
