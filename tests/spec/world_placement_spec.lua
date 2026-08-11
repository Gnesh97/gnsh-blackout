-- Phase 22 world placement registry tests.

TEST('world placement registry contains every configured physical entity', function()
    local expected = {
        'sandy_substation_01',
        'ls_central_substation_01',
        'sandy_tr_01',
        'blaine_south_tr_02',
        'ls_central_tr_01',
    }

    for _, logicalId in ipairs(expected) do
        local point = InfrastructureWorld[logicalId]
        ASSERT_TRUE(point ~= nil, 'missing world placement: ' .. logicalId)
        ASSERT_EQ(point.logicalId, logicalId, 'logical id mismatch')
        ASSERT_TRUE(point.coords ~= nil, 'missing coords: ' .. logicalId)
        ASSERT_TRUE(point.enabled, 'placement should be enabled: ' .. logicalId)
        ASSERT_TRUE(#point.expectedDistricts > 0, 'missing expected districts: ' .. logicalId)
    end
end)

TEST('transformer placement preserves feeder topology links', function()
    ASSERT_EQ(InfrastructureWorld.sandy_tr_01.feederId, 'blaine_south_feed_a')
    ASSERT_EQ(InfrastructureWorld.blaine_south_tr_02.feederId, 'blaine_south_feed_b')
    ASSERT_EQ(InfrastructureWorld.ls_central_tr_01.feederId, 'ls_central_feed_a')
end)

TEST('world registry passes static validation with current topology', function()
    local ok, errors = Validators.ValidateAll()
    ASSERT_TRUE(ok, 'world placement validation failed: ' .. table.concat(errors or {}, ' | '))
end)
