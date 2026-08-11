TEST('district calculation selects deterministic powered source feeder', function()
    local result = PowerCalculator.CalculateDistrict({
        { feederId = 'feed_b', powered = true, level = 1.0, status = Constants.GridStatus.ONLINE },
        { feederId = 'feed_a', powered = true, level = 1.0, status = Constants.GridStatus.ONLINE },
    })

    ASSERT_TRUE(result.powered, 'district should be powered')
    ASSERT_EQ(result.sourceFeederId, 'feed_a', 'same-level source must be deterministic')
end)

TEST('district calculation reports parent blocker only when all supply is blocked', function()
    local result = PowerCalculator.CalculateDistrict({
        {
            feederId = 'feed_a', powered = false, level = 0.0,
            status = Constants.GridStatus.BLACKOUT,
            blockedBy = { type = 'feeder', id = 'feed_a' },
        },
    })

    ASSERT_FALSE(result.powered, 'blocked district should be offline')
    ASSERT_EQ(result.blockedBy.type, 'feeder', 'blocker type must replicate')
    ASSERT_EQ(result.blockedBy.id, 'feed_a', 'blocker id must replicate')
end)

TEST('district state shape carries topology source fields', function()
    local state = Types.NewDistrictState('SANDY', {
        gridId = 'blaine_south',
        feederIds = { 'blaine_south_feed_a' },
        sourceFeederId = 'blaine_south_feed_a',
    })

    ASSERT_EQ(state.district, 'SANDY', 'district id must be present')
    ASSERT_EQ(state.gridId, 'blaine_south', 'grid id must be present')
    ASSERT_EQ(state.feederIds[1], 'blaine_south_feed_a', 'feeder list must be present')
    ASSERT_EQ(state.sourceFeederId, 'blaine_south_feed_a', 'source feeder must be present')
end)
