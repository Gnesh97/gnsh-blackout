TEST('power regions expose the requested admin scopes', function()
    local expected = { city = true, towns = true, south = true, vinewood = true, north = true }
    for _, region in ipairs(PowerRegions.GetAll()) do expected[region.id] = nil end
    for regionId in pairs(expected) do
        error('missing power region: ' .. regionId)
    end
end)

TEST('power region membership follows the intended coarse geography', function()
    local city = PowerRegions.Get('city')
    local towns = PowerRegions.Get('towns')
    local south = PowerRegions.Get('south')
    local vinewood = PowerRegions.Get('vinewood')
    local north = PowerRegions.Get('north')

    ASSERT_TRUE(city.districtSet.DOWNT, 'city must include Downtown')
    ASSERT_TRUE(city.districtSet.VINE, 'city must include Vinewood')
    ASSERT_FALSE(city.districtSet.SANDY, 'city must not include Sandy Shores')
    ASSERT_TRUE(towns.districtSet.SANDY, 'towns must include Sandy Shores')
    ASSERT_TRUE(towns.districtSet.GRAPES, 'towns must include Grapeseed')
    ASSERT_FALSE(towns.districtSet.DOWNT, 'towns must not include Downtown')
    ASSERT_TRUE(south.districtSet.DAVIS, 'South Side must include Davis')
    ASSERT_TRUE(south.districtSet.RANCHO, 'South Side must include Rancho')
    ASSERT_FALSE(south.districtSet.SANDY, 'South Side must not include Sandy Shores')
    ASSERT_TRUE(vinewood.districtSet.VINE, 'Vinewood must include Vinewood')
    ASSERT_TRUE(vinewood.districtSet.CHIL, 'Vinewood must include Vinewood Hills')
    ASSERT_FALSE(vinewood.districtSet.DAVIS, 'Vinewood must not include Davis')
    ASSERT_TRUE(north.districtSet.SANDY, 'North must include Sandy Shores')
    ASSERT_TRUE(north.districtSet.CANNY, 'North must include Raton Canyon')
    ASSERT_FALSE(north.districtSet.ALAMO, 'North must exclude water-only regions')
end)

TEST('power region district lists are sorted and duplicate-free', function()
    for _, region in ipairs(PowerRegions.GetAll()) do
        local seen = {}
        for index, districtCode in ipairs(region.districts) do
            ASSERT_FALSE(seen[districtCode], region.id .. ': duplicate district ' .. districtCode)
            ASSERT_TRUE(Districts.Exists(districtCode), region.id .. ': unknown district ' .. districtCode)
            ASSERT_FALSE(index > 1 and region.districts[index - 1] >= districtCode, region.id .. ': districts must be sorted')
            seen[districtCode] = true
        end
    end
end)
