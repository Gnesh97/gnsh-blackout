-- Citywide logical topology coverage.

TEST('every Los Santos city district has one grid assignment', function()
    -- district_registry_spec.lua intentionally exercises the assignment
    -- function with synthetic tables; restore the production index before
    -- asserting the citywide fixture.
    Districts.ComputeAssignments(Grids)
    local city = PowerRegions.Get('city')
    local seen = {}

    ASSERT_EQ(#city.districts, 51, 'city district count changed unexpectedly')
    for _, districtCode in ipairs(city.districts) do
        ASSERT_FALSE(seen[districtCode], 'city district appears twice: ' .. districtCode)
        ASSERT_EQ(Districts.GetAssignment(districtCode), 'ASSIGNED', districtCode .. ' is not assigned')
        ASSERT_TRUE(Districts.ByCode[districtCode].defaultGrid ~= nil, districtCode .. ' has no default grid')
        seen[districtCode] = true
    end
    ASSERT_TRUE(city.districtSet.TATAMO, 'Tataviam Mountains must be part of the city region')
end)

TEST('all enabled registry districts have one grid and one feeder', function()
    Districts.ComputeAssignments(Grids)
    local enabled = Districts.GetAllEnabled()
    local feederCount = {}

    ASSERT_EQ(#enabled, 91, 'expected 90 native districts plus HARMOSUB test zone')

    for _, code in ipairs(enabled) do
        ASSERT_EQ(Districts.GetAssignment(code), 'ASSIGNED', code .. ' is not assigned to a grid')
    end

    for _, feeder in pairs(Feeders) do
        for _, code in ipairs(feeder.districts or {}) do
            feederCount[code] = (feederCount[code] or 0) + 1
        end
    end

    for _, code in ipairs(enabled) do
        ASSERT_EQ(feederCount[code], 1, code .. ' must have exactly one feeder')
    end
end)

TEST('every city district is covered by exactly one feeder', function()
    local city = PowerRegions.Get('city')
    local citySet = city.districtSet
    local feederCount = {}

    for feederId, feeder in pairs(Feeders) do
        for _, districtCode in ipairs(feeder.districts) do
            if citySet[districtCode] then
                feederCount[districtCode] = (feederCount[districtCode] or 0) + 1
            end
        end
    end

    for _, districtCode in ipairs(city.districts) do
        ASSERT_EQ(feederCount[districtCode], 1, districtCode .. ' must have exactly one city feeder')
    end
end)

TEST('each configured grid has a multi-feeder substation and independent transformers', function()
    for gridId, grid in pairs(Grids) do
        ASSERT_EQ(#grid.substations, 1, gridId .. ' must have one primary substation')
        local substation = Substations[grid.substations[1]]
        ASSERT_TRUE(substation ~= nil, gridId .. ' substation is missing')
        ASSERT_TRUE(#substation.transformers >= 2, gridId .. ' needs multiple transformers')

        local claimedTransformers = {}
        local feederCount = 0
        for _, feeder in pairs(Feeders) do
            if feeder.substationId == grid.substations[1] then
                feederCount = feederCount + 1
                for _, transformerId in ipairs(feeder.transformers) do
                    ASSERT_FALSE(claimedTransformers[transformerId], transformerId .. ' is claimed by two feeders')
                    claimedTransformers[transformerId] = true
                end
            end
        end
        ASSERT_TRUE(feederCount >= 2, gridId .. ' needs multiple feeders')
        for _, transformerId in ipairs(substation.transformers) do
            ASSERT_TRUE(claimedTransformers[transformerId], transformerId .. ' is not connected to a feeder')
        end
    end
end)

TEST('unplaced city components stay logical-only and existing physical points stay enabled', function()
    ASSERT_TRUE(InfrastructureWorld.sandy_tr_01.physical)
    ASSERT_TRUE(InfrastructureWorld.sandy_tr_01.enabled)
    ASSERT_TRUE(InfrastructureWorld.ls_central_tr_01.physical)
    ASSERT_TRUE(InfrastructureWorld.ls_central_tr_01.enabled)

    for _, transformerId in ipairs({
        'ls_central_tr_02',
        'ls_south_tr_01', 'ls_south_tr_02',
        'ls_west_tr_01', 'ls_west_tr_02',
        'ls_vinewood_tr_01', 'ls_vinewood_tr_02',
        'ls_east_tr_01', 'ls_east_tr_02',
    }) do
        local point = InfrastructureWorld[transformerId]
        ASSERT_TRUE(point ~= nil, transformerId .. ' world record is missing')
        ASSERT_FALSE(point.physical, transformerId .. ' must not claim an unverified placement')
        ASSERT_FALSE(point.enabled, transformerId .. ' must not expose a fake interaction')
        ASSERT_TRUE(point.coords == nil, transformerId .. ' must not contain fake coordinates')
    end
end)

TEST('expanded topology passes static validation', function()
    local ok, errors = Validators.ValidateAll()
    ASSERT_TRUE(ok, 'expanded topology validation failed: ' .. table.concat(errors or {}, ' | '))
end)
