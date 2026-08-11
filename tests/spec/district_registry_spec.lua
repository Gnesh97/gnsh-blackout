--[[
    tests/spec/district_registry_spec.lua

    Phase 17 (Complete GTA District Registry). Covers the parts of
    shared/districts.lua that touch zero FiveM natives beyond the
    vector3() shim tests/run.lua already provides for AABB corners —
    same testability class as tests/spec/zone_resolver_spec.lua.

    Districts.ComputeAssignments() is exercised here against a small
    synthetic grids table (NOT the real shared/grids.lua Sandy topology,
    which loads and freezes Grids once at file-load time — re-running
    ComputeAssignments with a different table is exactly what these tests
    need, and doing it against a throwaway fixture keeps this file
    independent of whatever the real topology looks like this week).
]]

TEST('no duplicate district codes in the RAW table', function()
    local dupes = Districts.GetDuplicateCodes()
    ASSERT_EQ(#dupes, 0, 'shared/districts.lua RAW table has a duplicate code: ' .. table.concat(dupes, ', '))
end)

TEST('Exists: known code true, unknown code false', function()
    ASSERT_TRUE(Districts.Exists('SANDY'))
    ASSERT_FALSE(Districts.Exists('NOPE_NOT_A_REAL_CODE'))
end)

TEST('GetLabel: known code returns its label, unknown code echoes the code back', function()
    ASSERT_EQ(Districts.GetLabel('SANDY'), 'Sandy Shores')
    ASSERT_EQ(Districts.GetLabel('NOPE'), 'NOPE')
end)

TEST('every registry entry carries the full §17 district model shape', function()
    for code, entry in pairs(Districts.ByCode) do
        ASSERT_EQ(entry.id, code, code .. ': id must equal its own table key')
        ASSERT_EQ(entry.code, code, code .. ': code alias must equal its own table key')
        ASSERT_TRUE(entry.label ~= nil and entry.label ~= '', code .. ': missing label')
        ASSERT_TRUE(entry.enabled == true or entry.enabled == false, code .. ': enabled must be boolean')
        ASSERT_TRUE(entry.category ~= nil, code .. ': missing category')
        ASSERT_EQ(entry.resolver, Constants.Resolver.GTA_NATIVE, code .. ': resolver must be gta_native')
        ASSERT_EQ(entry.aabbConfidence, 'approx', code .. ': aabbConfidence should be approx until calibrated')
        ASSERT_TRUE(entry.aabb ~= nil and entry.aabb.min ~= nil and entry.aabb.max ~= nil, code .. ': missing aabb')
    end
end)

TEST('GetAllEnabled excludes disabled markers and is sorted', function()
    local enabled = Districts.GetAllEnabled()
    ASSERT_TRUE(#enabled > 0)

    local seenOceana, seenSanand = false, false
    for _, code in ipairs(enabled) do
        if code == 'OCEANA' then seenOceana = true end
        if code == 'SANAND' then seenSanand = true end
    end
    ASSERT_FALSE(seenOceana, 'OCEANA is enabled=false and must not appear in GetAllEnabled()')
    ASSERT_FALSE(seenSanand, 'SANAND is enabled=false and must not appear in GetAllEnabled()')

    for i = 2, #enabled do
        ASSERT_TRUE(enabled[i - 1] < enabled[i], 'GetAllEnabled() must be sorted')
    end
end)

TEST('GetAssignment: unknown code returns UNKNOWN before any ComputeAssignments call', function()
    ASSERT_EQ(Districts.GetAssignment('NOPE_NOT_A_REAL_CODE'), 'UNKNOWN')
end)

TEST('ComputeAssignments: a district claimed by a grid becomes ASSIGNED with the right defaultGrid', function()
    local fixtureGrids = {
        test_grid_1 = { districts = { 'SANDY', 'HARMO' } },
    }
    Districts.ComputeAssignments(fixtureGrids)

    ASSERT_EQ(Districts.GetAssignment('SANDY'), 'ASSIGNED')
    ASSERT_EQ(Districts.ByCode['SANDY'].defaultGrid, 'test_grid_1')
    ASSERT_EQ(Districts.GetAssignment('HARMO'), 'ASSIGNED')

    -- A registered, enabled code NOT listed by any fixture grid must come
    -- back UNASSIGNED, not silently powered/unpowered (spec §17.1).
    ASSERT_EQ(Districts.GetAssignment('DOWNT'), 'UNASSIGNED')
end)

TEST('ComputeAssignments: disabled markers stay UNASSIGNED even if never referenced (expected, not a bug)', function()
    Districts.ComputeAssignments({})
    ASSERT_EQ(Districts.GetAssignment('OCEANA'), 'UNASSIGNED')
    ASSERT_FALSE(Districts.ByCode['OCEANA'].enabled)
end)

TEST('SortedByVolume is ascending', function()
    local list = Districts.SortedByVolume
    for i = 2, #list do
        local prevVol = Utils.AABBVolume(list[i - 1].aabb.min, list[i - 1].aabb.max)
        local curVol = Utils.AABBVolume(list[i].aabb.min, list[i].aabb.max)
        ASSERT_TRUE(prevVol <= curVol, 'SortedByVolume must be non-decreasing')
    end
end)
