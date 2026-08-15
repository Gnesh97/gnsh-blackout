-- Receives a one-time, admin-authorized GetNameOfZone scan and persists the
-- validated geometry as a static NUI asset. No scan data is replicated during
-- normal gameplay or included in admin snapshots.

local scanSessions = {}
local sessionSequence = 0

local function exportConfig()
    return type(Config.DistrictMapExport) == 'table' and Config.DistrictMapExport or {}
end

local function notify(sourceId, success, message)
    TriggerClientEvent('gnsh-blackout:client:districtScanSaved', sourceId, success == true, message)
end

local function requireExporter(sourceId)
    local config = exportConfig()
    if config.enabled ~= true or not Config.IsDebugEnabled() then
        notify(sourceId, false, 'District tarayıcı yalnızca debug modunda kullanılabilir.')
        return false
    end
    local allowed = Security.RequireAdmin(sourceId)
    if allowed ~= true then
        notify(sourceId, false, 'District taraması için admin yetkisi gerekiyor.')
        return false
    end
    return true
end

local function isInteger(value, minimum, maximum)
    return type(value) == 'number' and value == value and value % 1 == 0
        and value >= minimum and value <= maximum
end

local function sameNumber(actual, expected)
    return type(actual) == 'number' and math.abs(actual - expected) < 0.001
end

local function validateGeometry(decoded, config)
    if type(decoded) ~= 'table' or decoded.version ~= 1 or decoded.source ~= 'GetNameOfZone' then
        return nil, 'geometri başlığı geçersiz'
    end
    if type(decoded.bounds) ~= 'table' or type(config.bounds) ~= 'table' then
        return nil, 'harita sınırları eksik'
    end
    for _, key in ipairs({ 'minX', 'maxX', 'minY', 'maxY' }) do
        if not sameNumber(decoded.bounds[key], config.bounds[key]) then
            return nil, ('harita sınırı uyuşmuyor: %s'):format(key)
        end
    end
    if not sameNumber(decoded.cellSize, config.cellSize) or not sameNumber(decoded.sampleZ, config.sampleZ) then
        return nil, 'tarama çözünürlüğü uyuşmuyor'
    end

    local expectedColumns = math.floor(((config.bounds.maxX - config.bounds.minX) / config.cellSize) + 0.5)
    local expectedRows = math.floor(((config.bounds.maxY - config.bounds.minY) / config.cellSize) + 0.5)
    if decoded.columns ~= expectedColumns or decoded.rows ~= expectedRows then
        return nil, 'tarama ızgarası uyuşmuyor'
    end
    if type(decoded.districts) ~= 'table' then return nil, 'district geometrileri eksik' end

    local itemCount = 0
    local districts = {}
    for code, district in pairs(decoded.districts) do
        local registryEntry = type(code) == 'string' and Districts.ByCode[code] or nil
        if not registryEntry or registryEntry.enabled == false then
            return nil, ('bilinmeyen veya kapalı district: %s'):format(tostring(code))
        end
        if type(district) ~= 'table' or type(district.runs) ~= 'table'
            or type(district.edges) ~= 'table' or type(district.gridBounds) ~= 'table' then
            return nil, ('district geometrisi eksik: %s'):format(code)
        end

        local clean = { runs = {}, edges = {}, gridBounds = {} }
        local gridBounds = district.gridBounds
        if not isInteger(gridBounds.minCol, 0, expectedColumns)
            or not isInteger(gridBounds.maxCol, 0, expectedColumns)
            or not isInteger(gridBounds.minRow, 0, expectedRows)
            or not isInteger(gridBounds.maxRow, 0, expectedRows)
            or gridBounds.minCol >= gridBounds.maxCol or gridBounds.minRow >= gridBounds.maxRow then
            return nil, ('district grid sınırı geçersiz: %s'):format(code)
        end
        clean.gridBounds = {
            minCol = gridBounds.minCol,
            maxCol = gridBounds.maxCol,
            minRow = gridBounds.minRow,
            maxRow = gridBounds.maxRow,
        }

        for index, run in ipairs(district.runs) do
            if type(run) ~= 'table' or #run ~= 3
                or not isInteger(run[1], 0, expectedRows - 1)
                or not isInteger(run[2], 0, expectedColumns)
                or not isInteger(run[3], 0, expectedColumns)
                or run[2] >= run[3] then
                return nil, ('district run geçersiz: %s/%d'):format(code, index)
            end
            clean.runs[index] = { run[1], run[2], run[3] }
            itemCount = itemCount + 1
        end

        for index, edge in ipairs(district.edges) do
            if type(edge) ~= 'table' or #edge ~= 4
                or not isInteger(edge[1], 0, expectedColumns)
                or not isInteger(edge[3], 0, expectedColumns)
                or not isInteger(edge[2], 0, expectedRows)
                or not isInteger(edge[4], 0, expectedRows)
                or (edge[1] ~= edge[3] and edge[2] ~= edge[4])
                or (edge[1] == edge[3] and edge[2] == edge[4]) then
                return nil, ('district kenarı geçersiz: %s/%d'):format(code, index)
            end
            clean.edges[index] = { edge[1], edge[2], edge[3], edge[4] }
            itemCount = itemCount + 1
        end
        districts[code] = clean
    end

    if itemCount == 0 then return nil, 'tarama hiç geometri üretmedi' end
    if itemCount > (tonumber(config.maxGeometryItems) or 1000000) then
        return nil, 'geometri öğesi güvenli sınırı aşıyor'
    end

    return {
        version = 1,
        source = 'GetNameOfZone',
        generatedAt = os.time(),
        gameBuild = tonumber(decoded.gameBuild),
        bounds = {
            minX = config.bounds.minX,
            maxX = config.bounds.maxX,
            minY = config.bounds.minY,
            maxY = config.bounds.maxY,
        },
        cellSize = config.cellSize,
        sampleZ = config.sampleZ,
        columns = expectedColumns,
        rows = expectedRows,
        districts = districts,
    }
end

RegisterNetEvent('gnsh-blackout:server:requestDistrictScan', function()
    local sourceId = source
    if not requireExporter(sourceId) then return end
    local existing = scanSessions[sourceId]
    if existing and os.time() - existing.startedAt > 900 then
        scanSessions[sourceId] = nil
    end
    if scanSessions[sourceId] then
        notify(sourceId, false, 'Bu oyuncu için zaten bir district taraması açık.')
        return
    end

    sessionSequence = sessionSequence + 1
    local token = ('district-scan:%d:%d:%d'):format(sourceId, os.time(), sessionSequence)
    scanSessions[sourceId] = { token = token, startedAt = os.time() }

    local config = exportConfig()
    TriggerClientEvent('gnsh-blackout:client:districtScanStart', sourceId, token, {
        bounds = {
            minX = config.bounds.minX,
            maxX = config.bounds.maxX,
            minY = config.bounds.minY,
            maxY = config.bounds.maxY,
        },
        cellSize = config.cellSize,
        sampleZ = config.sampleZ,
        callsPerFrame = config.callsPerFrame,
        latentBps = config.latentBps,
    })
end)

RegisterNetEvent('gnsh-blackout:server:districtScanCancelled', function(token)
    local sourceId = source
    local session = scanSessions[sourceId]
    if session and type(token) == 'string' and token == session.token then scanSessions[sourceId] = nil end
end)

RegisterNetEvent('gnsh-blackout:server:districtScanResult', function(token, payload)
    local sourceId = source
    local session = scanSessions[sourceId]
    scanSessions[sourceId] = nil
    if not session or type(token) ~= 'string' or token ~= session.token then
        notify(sourceId, false, 'District tarama oturumu geçersiz.')
        return
    end
    if os.time() - session.startedAt > 900 or not requireExporter(sourceId) then return end

    local config = exportConfig()
    if type(payload) ~= 'string' or #payload == 0
        or #payload > (tonumber(config.maxPayloadBytes) or (8 * 1024 * 1024)) then
        notify(sourceId, false, 'District tarama çıktısı boyut sınırını aşıyor.')
        return
    end

    local decodedOk, decoded = pcall(json.decode, payload)
    if not decodedOk then
        notify(sourceId, false, 'District tarama çıktısı geçerli JSON değil.')
        return
    end
    local geometry, validationError = validateGeometry(decoded, config)
    if not geometry then
        notify(sourceId, false, 'District tarama çıktısı reddedildi: ' .. tostring(validationError))
        return
    end

    local encoded = json.encode(geometry)
    local saved = SaveResourceFile(GetCurrentResourceName(), config.outputPath, encoded, #encoded)
    if saved == false then
        notify(sourceId, false, 'District geometri dosyası yazılamadı.')
        return
    end
    notify(sourceId, true, ('Native district geometrisi kaydedildi: %s. Resource restart sonrası panel kullanacak.')
        :format(config.outputPath))
end)

AddEventHandler('playerDropped', function()
    scanSessions[source] = nil
end)
