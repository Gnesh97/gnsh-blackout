-- Framework-free raster-to-vector accumulator used by the one-time native
-- district scanner. Rows are supplied north-to-south; coordinates stored in
-- the result are compact grid coordinates, not world coordinates.

DistrictGeometry = {}

local function isFiniteNumber(value)
    return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end

local function validOptions(options)
    if type(options) ~= 'table' or type(options.bounds) ~= 'table' then
        return false, 'options.bounds is required'
    end
    if not isFiniteNumber(options.cellSize) or options.cellSize <= 0 then
        return false, 'cellSize must be positive'
    end
    if type(options.columns) ~= 'number' or options.columns < 1 or options.columns % 1 ~= 0 then
        return false, 'columns must be a positive integer'
    end
    if type(options.rows) ~= 'number' or options.rows < 1 or options.rows % 1 ~= 0 then
        return false, 'rows must be a positive integer'
    end
    for _, key in ipairs({ 'minX', 'maxX', 'minY', 'maxY' }) do
        if not isFiniteNumber(options.bounds[key]) then
            return false, ('bounds.%s must be finite'):format(key)
        end
    end
    return true
end

local function compactEdges(edges)
    local groups = {}
    for _, edge in ipairs(edges) do
        local horizontal = edge[2] == edge[4]
        local fixed = horizontal and edge[2] or edge[1]
        local startValue = horizontal and math.min(edge[1], edge[3]) or math.min(edge[2], edge[4])
        local endValue = horizontal and math.max(edge[1], edge[3]) or math.max(edge[2], edge[4])
        local key = (horizontal and 'h:' or 'v:') .. tostring(fixed)
        groups[key] = groups[key] or { horizontal = horizontal, fixed = fixed, intervals = {} }
        groups[key].intervals[#groups[key].intervals + 1] = { startValue, endValue }
    end

    local result = {}
    for _, group in pairs(groups) do
        table.sort(group.intervals, function(a, b)
            if a[1] == b[1] then return a[2] < b[2] end
            return a[1] < b[1]
        end)
        local current
        for _, interval in ipairs(group.intervals) do
            if not current then
                current = { interval[1], interval[2] }
            elseif interval[1] <= current[2] then
                current[2] = math.max(current[2], interval[2])
            else
                if group.horizontal then
                    result[#result + 1] = { current[1], group.fixed, current[2], group.fixed }
                else
                    result[#result + 1] = { group.fixed, current[1], group.fixed, current[2] }
                end
                current = { interval[1], interval[2] }
            end
        end
        if current then
            if group.horizontal then
                result[#result + 1] = { current[1], group.fixed, current[2], group.fixed }
            else
                result[#result + 1] = { group.fixed, current[1], group.fixed, current[2] }
            end
        end
    end
    table.sort(result, function(a, b)
        for index = 1, 4 do
            if a[index] ~= b[index] then return a[index] < b[index] end
        end
        return false
    end)
    return result
end

function DistrictGeometry.CreateAccumulator(options)
    local valid, err = validOptions(options)
    if not valid then error(err, 2) end

    local rowIndex = 0
    local previousRow = {}
    local districts = {}
    local finished = false

    local function acceptedCode(value)
        if type(value) ~= 'string' or value == '' then return nil end
        if type(options.acceptCode) == 'function' and options.acceptCode(value) ~= true then return nil end
        return value
    end

    local function getDistrict(code)
        if not code then return nil end
        local district = districts[code]
        if district then return district end
        district = {
            runs = {},
            edges = {},
            gridBounds = {
                minCol = options.columns,
                maxCol = 0,
                minRow = options.rows,
                maxRow = 0,
            },
        }
        districts[code] = district
        return district
    end

    local function addEdge(code, x1, y1, x2, y2)
        local district = getDistrict(code)
        if not district then return end
        district.edges[#district.edges + 1] = { x1, y1, x2, y2 }
    end

    local function addRun(code, row, startCol, endCol)
        local district = getDistrict(code)
        if not district then return end
        district.runs[#district.runs + 1] = { row, startCol, endCol }
        local bounds = district.gridBounds
        bounds.minCol = math.min(bounds.minCol, startCol)
        bounds.maxCol = math.max(bounds.maxCol, endCol)
        bounds.minRow = math.min(bounds.minRow, row)
        bounds.maxRow = math.max(bounds.maxRow, row + 1)
    end

    local accumulator = {}

    function accumulator:AddRow(row)
        if finished then return false, 'scan is already finished' end
        if type(row) ~= 'table' then return false, 'row must be a table' end
        if rowIndex >= options.rows then return false, 'too many rows' end

        local normalized = {}
        for column = 1, options.columns do
            normalized[column] = acceptedCode(row[column]) or false
        end

        local runCode = nil
        local runStart = 0
        for gridColumn = 0, options.columns do
            local nextCode = gridColumn < options.columns and normalized[gridColumn + 1] or nil
            if nextCode ~= runCode then
                if runCode then addRun(runCode, rowIndex, runStart, gridColumn) end
                if runCode or nextCode then
                    addEdge(runCode, gridColumn, rowIndex, gridColumn, rowIndex + 1)
                    addEdge(nextCode, gridColumn, rowIndex, gridColumn, rowIndex + 1)
                end
                runCode = nextCode
                runStart = gridColumn
            end
        end

        for column = 1, options.columns do
            local previousCode = previousRow[column] or nil
            local currentCode = normalized[column] or nil
            if previousCode ~= currentCode then
                addEdge(previousCode, column - 1, rowIndex, column, rowIndex)
                addEdge(currentCode, column - 1, rowIndex, column, rowIndex)
            end
        end

        previousRow = normalized
        rowIndex = rowIndex + 1
        return true
    end

    function accumulator:Finish()
        if finished then return nil, 'scan is already finished' end
        if rowIndex ~= options.rows then
            return nil, ('incomplete scan: expected %d rows, got %d'):format(options.rows, rowIndex)
        end
        finished = true

        for column = 1, options.columns do
            local code = previousRow[column] or nil
            addEdge(code, column - 1, rowIndex, column, rowIndex)
        end
        for _, district in pairs(districts) do
            district.edges = compactEdges(district.edges)
        end

        return {
            version = 1,
            source = 'GetNameOfZone',
            bounds = {
                minX = options.bounds.minX,
                maxX = options.bounds.maxX,
                minY = options.bounds.minY,
                maxY = options.bounds.maxY,
            },
            cellSize = options.cellSize,
            sampleZ = tonumber(options.sampleZ) or 0,
            columns = options.columns,
            rows = options.rows,
            districts = districts,
        }
    end

    return accumulator
end
