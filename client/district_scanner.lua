-- One-time native district geometry exporter. This never runs on resource
-- start or when the admin NUI opens; an authorized developer must explicitly
-- invoke /districtscan while debug mode is enabled.

local scanRunning = false
local scanCancelled = false

local function positiveInteger(value, fallback)
    local number = math.floor(tonumber(value) or fallback)
    if number < 1 then return fallback end
    return number
end

local function validScanSpec(spec)
    if type(spec) ~= 'table' or type(spec.bounds) ~= 'table' then return false end
    local bounds = spec.bounds
    local cellSize = tonumber(spec.cellSize)
    local minX, maxX = tonumber(bounds.minX), tonumber(bounds.maxX)
    local minY, maxY = tonumber(bounds.minY), tonumber(bounds.maxY)
    return cellSize and cellSize > 0
        and minX and maxX and minY and maxY
        and maxX > minX and maxY > minY
end

local function acceptedDistrict(code)
    local entry = type(code) == 'string' and Districts.ByCode[code] or nil
    return entry ~= nil and entry.enabled ~= false
end

local function scanNativeDistricts(token, spec)
    if scanRunning or not validScanSpec(spec) or type(token) ~= 'string' then return end
    scanRunning = true
    scanCancelled = false

    CreateThread(function()
        local bounds = spec.bounds
        local cellSize = tonumber(spec.cellSize)
        local columns = math.floor(((bounds.maxX - bounds.minX) / cellSize) + 0.5)
        local rows = math.floor(((bounds.maxY - bounds.minY) / cellSize) + 0.5)
        local sampleZ = tonumber(spec.sampleZ) or 0.0
        local callsPerFrame = positiveInteger(spec.callsPerFrame, 1200)
        local samplesSinceYield = 0
        local unknownCodes = {}
        local accumulator = DistrictGeometry.CreateAccumulator({
            bounds = bounds,
            cellSize = cellSize,
            columns = columns,
            rows = rows,
            sampleZ = sampleZ,
            acceptCode = acceptedDistrict,
        })

        print(('[gnsh-blackout] native district scan started: %dx%d, %.1fm cells (%d samples)')
            :format(columns, rows, cellSize, columns * rows))

        local lastPercent = -1
        for row = 0, rows - 1 do
            if scanCancelled then
                scanRunning = false
                TriggerServerEvent('gnsh-blackout:server:districtScanCancelled', token)
                print('[gnsh-blackout] native district scan cancelled.')
                return
            end

            local labels = {}
            local y = bounds.maxY - ((row + 0.5) * cellSize)
            for column = 0, columns - 1 do
                local x = bounds.minX + ((column + 0.5) * cellSize)
                local code = GetNameOfZone(x, y, sampleZ)
                if acceptedDistrict(code) then
                    labels[column + 1] = code
                else
                    labels[column + 1] = false
                    if type(code) == 'string' and code ~= '' then unknownCodes[code] = true end
                end

                samplesSinceYield = samplesSinceYield + 1
                if samplesSinceYield >= callsPerFrame then
                    samplesSinceYield = 0
                    Wait(0)
                end
            end

            local added, addErr = accumulator:AddRow(labels)
            if not added then
                scanRunning = false
                TriggerServerEvent('gnsh-blackout:server:districtScanCancelled', token)
                print(('^1[gnsh-blackout] district scan failed: %s^7'):format(tostring(addErr)))
                return
            end

            local percent = math.floor(((row + 1) / rows) * 100)
            if percent >= lastPercent + 5 then
                lastPercent = percent
                print(('[gnsh-blackout] native district scan: %d%%'):format(percent))
            end
        end

        local geometry, geometryErr = accumulator:Finish()
        if not geometry then
            scanRunning = false
            TriggerServerEvent('gnsh-blackout:server:districtScanCancelled', token)
            print(('^1[gnsh-blackout] district geometry failed: %s^7'):format(tostring(geometryErr)))
            return
        end

        geometry.gameBuild = type(GetGameBuildNumber) == 'function' and GetGameBuildNumber() or nil
        geometry.unknownCodes = {}
        for code in pairs(unknownCodes) do geometry.unknownCodes[#geometry.unknownCodes + 1] = code end
        table.sort(geometry.unknownCodes)

        local encodedOk, payload = pcall(json.encode, geometry)
        if not encodedOk or type(payload) ~= 'string' then
            scanRunning = false
            TriggerServerEvent('gnsh-blackout:server:districtScanCancelled', token)
            print('^1[gnsh-blackout] district geometry could not be encoded.^7')
            return
        end

        print(('[gnsh-blackout] scan complete; uploading %.2f MB...'):format(#payload / 1048576))
        TriggerLatentServerEvent(
            'gnsh-blackout:server:districtScanResult',
            positiveInteger(spec.latentBps, 1000000),
            token,
            payload
        )
        scanRunning = false
    end)
end

RegisterNetEvent('gnsh-blackout:client:districtScanStart', scanNativeDistricts)

RegisterNetEvent('gnsh-blackout:client:districtScanSaved', function(success, message)
    print(((success and '^2' or '^1') .. '[gnsh-blackout] %s^7'):format(tostring(message)))
end)

local exportConfig = Config.DistrictMapExport or {}
RegisterCommand(exportConfig.command or 'districtscan', function()
    if scanRunning then
        print('[gnsh-blackout] a native district scan is already running.')
        return
    end
    TriggerServerEvent('gnsh-blackout:server:requestDistrictScan')
end, false)

RegisterCommand(exportConfig.cancelCommand or 'districtscancancel', function()
    if not scanRunning then
        print('[gnsh-blackout] no native district scan is running.')
        return
    end
    scanCancelled = true
end, false)
