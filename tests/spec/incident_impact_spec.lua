-- Phase 23: topology-level incident impact is deterministic and server-owned.

local function assertDistricts(actual, expected, label)
    ASSERT_EQ(#actual, #expected, label .. ': district count')
    local seen = {}
    for _, districtId in ipairs(actual) do seen[districtId] = true end
    for _, districtId in ipairs(expected) do
        ASSERT_TRUE(seen[districtId], label .. ': missing district ' .. districtId)
    end
end

TEST('incident impact: transformer resolves one feeder and its districts', function()
    local impact = IncidentImpact.Calculate('transformer', 'sandy_tr_01')
    ASSERT_EQ(impact.gridId, 'blaine_south')
    ASSERT_EQ(impact.substationId, 'sandy_substation_01')
    ASSERT_EQ(impact.feederId, 'blaine_south_feed_a')
    assertDistricts(impact.affectedDistricts, { 'SANDY', 'HARMO' }, 'transformer')
    ASSERT_EQ(impact.estimatedImpact.districtCount, 2)
end)

TEST('incident impact: feeder affects only its own districts', function()
    local impact = IncidentImpact.Calculate('feeder', 'blaine_south_feed_b')
    ASSERT_EQ(impact.gridId, 'blaine_south')
    ASSERT_EQ(impact.substationId, 'sandy_substation_01')
    ASSERT_EQ(impact.feederId, 'blaine_south_feed_b')
    assertDistricts(impact.affectedDistricts, { 'DESRT' }, 'feeder')
    ASSERT_EQ(impact.estimatedImpact.districtCount, 1)
end)

TEST('incident impact: substation aggregates all child feeders', function()
    local impact = IncidentImpact.Calculate('substation', 'sandy_substation_01')
    ASSERT_EQ(impact.gridId, 'blaine_south')
    assertDistricts(impact.affectedDistricts, { 'SANDY', 'HARMO', 'DESRT' }, 'substation')
    ASSERT_EQ(impact.estimatedImpact.districtCount, 3)
end)

TEST('incident impact: grid aggregates its complete topology', function()
    local impact = IncidentImpact.Calculate('grid', 'ls_central')
    ASSERT_EQ(impact.gridId, 'ls_central')
    assertDistricts(impact.affectedDistricts, { 'DOWNT', 'PBOX', 'SKID' }, 'grid')
    ASSERT_EQ(impact.estimatedImpact.districtCount, 3)
end)

TEST('incident impact: unknown target fails closed', function()
    local impact, err = IncidentImpact.Calculate('grid', 'fake_grid')
    ASSERT_EQ(impact, nil)
    ASSERT_TRUE(type(err) == 'string' and #err > 0)
end)
