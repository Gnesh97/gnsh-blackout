local function newAccumulator(columns, rows, accepted)
    return DistrictGeometry.CreateAccumulator({
        bounds = { minX = 0, maxX = columns * 10, minY = 0, maxY = rows * 10 },
        cellSize = 10,
        columns = columns,
        rows = rows,
        sampleZ = 0,
        acceptCode = function(code)
            return accepted[code] == true
        end,
    })
end

TEST('district geometry builds compact runs and a closed outline', function()
    local accumulator = newAccumulator(2, 2, { A = true })
    ASSERT_TRUE(accumulator:AddRow({ 'A', 'A' }))
    ASSERT_TRUE(accumulator:AddRow({ 'A', 'A' }))

    local geometry = accumulator:Finish()
    local district = geometry.districts.A
    ASSERT_TRUE(district ~= nil)
    ASSERT_EQ(#district.runs, 2)
    ASSERT_EQ(#district.edges, 4)
    ASSERT_EQ(district.gridBounds.minCol, 0)
    ASSERT_EQ(district.gridBounds.maxCol, 2)
    ASSERT_EQ(district.gridBounds.minRow, 0)
    ASSERT_EQ(district.gridBounds.maxRow, 2)
end)

TEST('district geometry keeps a shared border on both districts', function()
    local accumulator = newAccumulator(2, 2, { A = true, B = true })
    accumulator:AddRow({ 'A', 'B' })
    accumulator:AddRow({ 'A', 'B' })

    local geometry = accumulator:Finish()
    ASSERT_EQ(#geometry.districts.A.runs, 2)
    ASSERT_EQ(#geometry.districts.B.runs, 2)
    ASSERT_EQ(#geometry.districts.A.edges, 4)
    ASSERT_EQ(#geometry.districts.B.edges, 4)
end)

TEST('district geometry treats rejected zone codes as empty map cells', function()
    local accumulator = newAccumulator(2, 1, { A = true })
    accumulator:AddRow({ 'A', 'OCEANA' })

    local geometry = accumulator:Finish()
    ASSERT_TRUE(geometry.districts.A ~= nil)
    ASSERT_TRUE(geometry.districts.OCEANA == nil)
    ASSERT_EQ(geometry.districts.A.gridBounds.maxCol, 1)
end)

TEST('district geometry rejects malformed rows and incomplete scans', function()
    local accumulator = newAccumulator(2, 2, { A = true })
    local ok = accumulator:AddRow('not-a-row')
    ASSERT_FALSE(ok)
    accumulator:AddRow({ 'A', 'A' })
    local geometry, err = accumulator:Finish()
    ASSERT_TRUE(geometry == nil)
    ASSERT_TRUE(type(err) == 'string' and err ~= '')
end)
