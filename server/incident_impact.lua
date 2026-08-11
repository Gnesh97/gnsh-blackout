--[[
    server/incident_impact.lua

    Server-authoritative topology impact calculation for Phase 23. This
    module has no side effects: it resolves a target into its topology path,
    affected districts, a current player estimate, and an approximate world
    location. IncidentManager owns lifecycle and persistence; this module
    only answers "what would this target affect?".
]]

IncidentImpact = {}

local function appendUnique(list, seen, value)
    if type(value) ~= 'string' or value == '' or seen[value] then return end
    seen[value] = true
    list[#list + 1] = value
end

local function appendDistricts(list, seen, districts)
    for _, districtId in ipairs(districts or {}) do
        appendUnique(list, seen, districtId)
    end
end

local function locationFromPoint(point)
    local coords = point and point.coords
    if not coords then return nil end
    return { x = coords.x, y = coords.y, z = coords.z }
end

local function locationForTarget(targetType, targetId, transformerIds, substationIds)
    if InfrastructureWorld and InfrastructureWorld[targetId] then
        return locationFromPoint(InfrastructureWorld[targetId])
    end

    if targetType == Constants.ComponentType.FEEDER then
        for _, transformerId in ipairs(transformerIds or {}) do
            local point = InfrastructureWorld and InfrastructureWorld[transformerId]
            if point then return locationFromPoint(point) end
        end
    end

    for _, substationId in ipairs(substationIds or {}) do
        local point = InfrastructureWorld and InfrastructureWorld[substationId]
        if point then return locationFromPoint(point) end
    end

    for _, transformerId in ipairs(transformerIds or {}) do
        local point = InfrastructureWorld and InfrastructureWorld[transformerId]
        if point then return locationFromPoint(point) end
    end

    return nil
end

local function estimatePlayers(affectedDistricts)
    local affected = {}
    for _, districtId in ipairs(affectedDistricts) do affected[districtId] = true end

    if type(GetPlayers) ~= 'function' or type(GetPlayerPed) ~= 'function'
        or type(GetEntityCoords) ~= 'function' or not ServerZone then
        return 0
    end

    local count = 0
    local players = GetPlayers()
    for _, playerId in ipairs(players or {}) do
        local ped = GetPlayerPed(playerId)
        if ped and ped ~= 0 then
            local ok, coords = pcall(GetEntityCoords, ped)
            if ok and coords then
                local districtId = ServerZone.ResolveDistrictOnly(coords)
                if districtId and affected[districtId] then count = count + 1 end
            end
        end
    end

    return count
end

local function resolveTarget(targetType, targetId)
    if targetType == Constants.ComponentType.GRID then
        local grid = Grids[targetId]
        if not grid then return nil, ('unknown grid "%s"'):format(tostring(targetId)) end
        return {
            gridId = targetId,
            substationIds = Utils.ShallowCopy(grid.substations or {}),
            transformerIds = GridManager.GetTransformersForGrid(targetId),
            districts = Utils.ShallowCopy(grid.districts or {}),
        }
    end

    if targetType == Constants.ComponentType.SUBSTATION then
        local gridId = GridManager.GetGridForSubstation(targetId)
        if not gridId then return nil, ('unknown substation "%s"'):format(tostring(targetId)) end
        local feederIds = GridManager.GetFeedersForSubstation(targetId)
        local transformerIds = {}
        local districts = {}
        local seen = {}
        for _, feederId in ipairs(feederIds) do
            local feeder = Feeders[feederId]
            appendDistricts(districts, seen, feeder and feeder.districts)
            for _, transformerId in ipairs(GridManager.GetTransformersForFeeder(feederId)) do
                transformerIds[#transformerIds + 1] = transformerId
            end
        end
        if #districts == 0 then
            local grid = Grids[gridId]
            appendDistricts(districts, seen, grid and grid.districts)
        end
        return {
            gridId = gridId,
            substationIds = { targetId },
            feederIds = feederIds,
            transformerIds = transformerIds,
            districts = districts,
        }
    end

    if targetType == Constants.ComponentType.FEEDER then
        local feeder = Feeders[targetId]
        local substationId = feeder and feeder.substationId
        local gridId = substationId and GridManager.GetGridForSubstation(substationId)
        if not feeder or not gridId then return nil, ('unknown feeder "%s"'):format(tostring(targetId)) end
        return {
            gridId = gridId,
            substationIds = { substationId },
            feederIds = { targetId },
            transformerIds = GridManager.GetTransformersForFeeder(targetId),
            districts = Utils.ShallowCopy(feeder.districts or {}),
        }
    end

    if targetType == Constants.ComponentType.TRANSFORMER then
        local gridId = GridManager.GetGridForTransformer(targetId)
        local substationId = GridManager.GetSubstationForTransformer(targetId)
        local feederId = GridManager.GetFeederForTransformer(targetId)
        local transformer = Transformers[targetId]
        if not transformer or not gridId or not substationId then
            return nil, ('unknown transformer "%s"'):format(tostring(targetId))
        end
        local feeder = feederId and Feeders[feederId]
        local grid = Grids[gridId]
        return {
            gridId = gridId,
            substationIds = { substationId },
            feederIds = feederId and { feederId } or {},
            transformerIds = { targetId },
            districts = Utils.ShallowCopy((feeder and feeder.districts) or (grid and grid.districts) or {}),
            feederId = feederId,
        }
    end

    return nil, ('unsupported incident target type "%s"'):format(tostring(targetType))
end

function IncidentImpact.Calculate(targetType, targetId)
    local resolved, err = resolveTarget(targetType, targetId)
    if not resolved then return nil, err end

    local affectedDistricts = {}
    local seenDistricts = {}
    appendDistricts(affectedDistricts, seenDistricts, resolved.districts)

    local location = locationForTarget(
        targetType,
        targetId,
        resolved.transformerIds,
        resolved.substationIds
    )

    return {
        targetType = targetType,
        targetId = targetId,
        gridId = resolved.gridId,
        substationId = resolved.substationIds and resolved.substationIds[1] or nil,
        feederId = resolved.feederId or (resolved.feederIds and resolved.feederIds[1] or nil),
        transformerId = targetType == Constants.ComponentType.TRANSFORMER and targetId
            or (resolved.transformerIds and #resolved.transformerIds == 1 and resolved.transformerIds[1] or nil),
        affectedDistricts = affectedDistricts,
        estimatedImpact = {
            districtCount = #affectedDistricts,
            playerCount = estimatePlayers(affectedDistricts),
        },
        approximateLocation = location,
    }
end

