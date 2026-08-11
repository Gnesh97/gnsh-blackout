-- Phase 29 recovery invariants through the production district calculator.

local function feeder(id, powered, level, blockedBy)
    return {
        feederId = id,
        powered = powered,
        level = level,
        blockedBy = blockedBy,
    }
end

TEST('one online feeder keeps district online while another feeder is offline', function()
    local result = PowerCalculator.CalculateDistrict({
        feeder('feeder_a', true, 1.0),
        feeder('feeder_b', false, 0.0, { type = 'feeder', id = 'feeder_b' }),
    })
    ASSERT_TRUE(result.powered)
    ASSERT_EQ(result.status, Constants.GridStatus.ONLINE)
end)

TEST('all feeders offline keep district offline', function()
    local result = PowerCalculator.CalculateDistrict({
        feeder('feeder_a', false, 0.0, { type = 'substation', id = 'sub_a' }),
        feeder('feeder_b', false, 0.0, { type = 'grid', id = 'grid_a' }),
    })
    ASSERT_FALSE(result.powered)
    ASSERT_EQ(result.status, Constants.GridStatus.BLACKOUT)
end)

TEST('parent restore does not revive an offline child', function()
    local result = PowerCalculator.CalculateDistrict({
        feeder('feeder_a', false, 0.0, { type = 'transformer', id = 'tr_a' }),
    })
    ASSERT_FALSE(result.powered)
    ASSERT_EQ(result.status, Constants.GridStatus.BLACKOUT)
end)

TEST('child restore becomes online after its parent is available', function()
    local result = PowerCalculator.CalculateDistrict({
        feeder('feeder_a', true, 1.0),
    })
    ASSERT_TRUE(result.powered)
    ASSERT_EQ(result.status, Constants.GridStatus.ONLINE)
end)
