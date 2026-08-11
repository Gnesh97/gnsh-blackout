-- Phase 24: public API's pure copy and input-validation contract.

TEST('api deep copy detaches nested runtime state', function()
    local source = {
        blockedBy = { type = 'feeder', id = 'blaine_south_feed_a' },
        metadata = { affected = { 'SANDY', 'HARMO' } },
    }
    local copy = ApiHelpers.DeepCopy(source)

    copy.blockedBy.id = 'fake_feeder'
    copy.metadata.affected[1] = 'FAKE'

    ASSERT_EQ(source.blockedBy.id, 'blaine_south_feed_a', 'blockedBy must be detached')
    ASSERT_EQ(source.metadata.affected[1], 'SANDY', 'nested arrays must be detached')
end)

TEST('api deep copy preserves primitive values and nil', function()
    local source = { powered = true, level = 1.0, missing = nil }
    local copy = ApiHelpers.DeepCopy(source)

    ASSERT_TRUE(copy.powered, 'boolean value was not copied')
    ASSERT_EQ(copy.level, 1.0, 'number value was not copied')
    ASSERT_EQ(copy.missing, nil, 'nil value should remain nil')
end)

TEST('api coordinate validation accepts finite vector-like coordinates', function()
    local ok, err = ApiHelpers.ValidateCoordinates({ x = 1961.0, y = 3745.0, z = 32.5 })
    ASSERT_TRUE(ok, err)
end)

TEST('api coordinate validation rejects malformed coordinates', function()
    local ok = ApiHelpers.ValidateCoordinates({ x = 1961.0, y = '3745', z = 32.5 })
    ASSERT_FALSE(ok, 'string coordinate must be rejected')

    ok = ApiHelpers.ValidateCoordinates({ x = 0 / 0, y = 0, z = 0 })
    ASSERT_FALSE(ok, 'NaN coordinate must be rejected')
end)

TEST('api identifiers normalize safely', function()
    ASSERT_EQ(ApiHelpers.NormalizeIdentifier('  feeder_a '), 'feeder_a', 'identifier trim failed')
    ASSERT_EQ(ApiHelpers.NormalizeDistrict(' sandy '), 'SANDY', 'district normalization failed')
    ASSERT_EQ(ApiHelpers.NormalizeIdentifier('   '), nil, 'blank identifier must be rejected')
end)
