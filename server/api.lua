--[[
    server/api.lua

    Public export surface (spec §48, Phase 24).  External resources should
    normally call IsPositionPowered(coords); the topology-aware exports are
    available when an integration genuinely needs feeder/path details.

    This module owns no power state.  It reads server-authoritative managers
    and returns detached copies, so an external resource can never mutate the
    runtime cache by changing an API result.
]]

InfrastructureApi = {}

local function copy(value)
    return ApiHelpers.DeepCopy(value)
end

local function unknown(kind, id)
    return nil, ('unknown %s "%s"'):format(kind, tostring(id))
end

local function validateRegistryId(registry, kind, id)
    local normalized = ApiHelpers.NormalizeIdentifier(id)
    if not normalized or not registry[normalized] then
        return unknown(kind, id)
    end
    return normalized
end

local function defaultGridState(gridId)
    return {
        gridId = gridId,
        powered = true,
        level = 1.0,
        status = Constants.GridStatus.ONLINE,
        revision = 0,
        forcedOffline = false,
        blockedBy = nil,
    }
end

local function defaultDistrictState(districtId, gridId)
    return {
        district = districtId,
        gridId = gridId,
        feederIds = {},
        sourceFeederId = nil,
        powered = true,
        level = 1.0,
        status = Constants.GridStatus.ONLINE,
        revision = 0,
        blockedBy = nil,
    }
end

local function appendUnique(list, seen, value)
    if not value or seen[value] then return end
    seen[value] = true
    list[#list + 1] = value
end

local function feederIdsForGrid(gridId)
    local ids = {}
    for _, feederId in ipairs(GridManager.GetAllFeederIds()) do
        local substationId = GridManager.GetSubstationForFeeder(feederId)
        if GridManager.GetGridForSubstation(substationId) == gridId then
            ids[#ids + 1] = feederId
        end
    end
    table.sort(ids)
    return ids
end

local function stateForGrid(gridId)
    return Replication.GetGridState(gridId) or defaultGridState(gridId)
end

local function stateForDistrict(districtId, gridId)
    return Replication.GetDistrictState(districtId) or defaultDistrictState(districtId, gridId)
end

local function buildPowerPath(districtId, gridId)
    local grid = Grids[gridId]
    local districtState = districtId and stateForDistrict(districtId, gridId) or nil
    local gridState = stateForGrid(gridId)
    local feederIds = districtId
        and GridManager.GetFeedersForDistrict(districtId)
        or feederIdsForGrid(gridId)

    local substationIds = {}
    local substationSeen = {}
    local transformerIds = {}
    local transformerSeen = {}
    local feederEntries = {}

    for _, feederId in ipairs(feederIds) do
        local feeder = Feeders[feederId]
        local substationId = feeder and feeder.substationId
        appendUnique(substationIds, substationSeen, substationId)

        local feederTransformerIds = GridManager.GetTransformersForFeeder(feederId)
        for _, transformerId in ipairs(feederTransformerIds) do
            appendUnique(transformerIds, transformerSeen, transformerId)
        end

        local feederState = FeederManager.GetState(feederId)
        feederEntries[#feederEntries + 1] = {
            feederId = feederId,
            substationId = substationId,
            districts = feeder and copy(feeder.districts) or {},
            transformerIds = copy(feederTransformerIds),
            state = copy(feederState),
        }
    end

    -- A grid-assigned district with no explicit feeder uses the grid fallback
    -- path.  Include the complete static branch so the API still describes
    -- grid -> substation -> transformer rather than returning a partial path.
    if #feederIds == 0 then
        for _, substationId in ipairs((grid and grid.substations) or {}) do
            appendUnique(substationIds, substationSeen, substationId)
        end
        for _, transformerId in ipairs(GridManager.GetTransformersForGrid(gridId)) do
            appendUnique(transformerIds, transformerSeen, transformerId)
        end
    end

    local substationEntries = {}
    for _, substationId in ipairs(substationIds) do
        substationEntries[#substationEntries + 1] = {
            substationId = substationId,
            gridId = GridManager.GetGridForSubstation(substationId),
            feederIds = copy(GridManager.GetFeedersForSubstation(substationId)),
            state = copy(SubstationManager.GetState(substationId)),
        }
    end

    local transformerEntries = {}
    for _, transformerId in ipairs(transformerIds) do
        transformerEntries[#transformerEntries + 1] = {
            transformerId = transformerId,
            feederId = GridManager.GetFeederForTransformer(transformerId),
            substationId = GridManager.GetSubstationForTransformer(transformerId),
            state = copy(TransformerManager.GetState(transformerId)),
        }
    end

    local powered
    local level
    local status
    local revision
    local blockedBy
    if districtState then
        -- Do not use the Lua `a and b or c` idiom here: powered=false is a
        -- valid state and must not fall through to the grid's true value.
        powered = districtState.powered
        level = districtState.level
        status = districtState.status
        revision = districtState.revision
        blockedBy = districtState.blockedBy
    else
        powered = gridState.powered
        level = gridState.level
        status = gridState.status
        revision = gridState.revision
        blockedBy = gridState.blockedBy
    end
    local sourceFeederId = districtState and districtState.sourceFeederId or feederIds[1]

    return {
        district = districtId,
        managed = true,
        gridId = gridId,
        substationId = substationIds[1],
        substationIds = substationIds,
        feederIds = feederIds,
        sourceFeederId = sourceFeederId,
        transformerIds = transformerIds,
        powered = powered == true,
        level = level or 0.0,
        status = status,
        revision = revision or 0,
        blockedBy = copy(blockedBy),
        gridState = copy(gridState),
        substations = substationEntries,
        feeders = feederEntries,
        transformers = transformerEntries,
        districtState = copy(districtState),
    }
end

local function unassignedPath(coords, districtId)
    return {
        coords = coords and ApiHelpers.CopyCoordinates(coords) or nil,
        district = districtId,
        managed = false,
        gridId = nil,
        substationId = nil,
        substationIds = {},
        feederIds = {},
        sourceFeederId = nil,
        transformerIds = {},
        powered = true,
        level = 1.0,
        status = Constants.GridStatus.ONLINE,
        revision = 0,
        blockedBy = nil,
    }
end

local function isGridPowered(gridId)
    local id, err = validateRegistryId(Grids, 'grid', gridId)
    if not id then return nil, err end

    local state = Replication.GetGridState(id)
    if not state then return true end
    return state.powered == true
end

local function isDistrictPowered(districtId)
    local id = ApiHelpers.NormalizeDistrict(districtId)
    if not id or not Districts.Exists(id) then
        return unknown('district', districtId)
    end

    local state = Replication.GetDistrictState(id)
    -- Recognized but unassigned districts deliberately fail open.
    if not state then return true end
    return state.powered == true
end

local function isPositionPowered(coords)
    local valid = ApiHelpers.ValidateCoordinates(coords)
    if not valid then return true end

    local gridId, district = ServerZone.ResolvePosition(coords)
    if district then
        local powered = isDistrictPowered(district)
        return powered == nil and true or powered
    end
    if gridId then
        local powered = isGridPowered(gridId)
        return powered == nil and true or powered
    end
    return true
end

local function getPublishedGridState(gridId)
    local id, err = validateRegistryId(Grids, 'grid', gridId)
    if not id then return nil, err end
    return copy(Replication.GetGridState(id))
end

local function getPublishedDistrictState(districtId)
    local id = ApiHelpers.NormalizeDistrict(districtId)
    if not id or not Districts.Exists(id) then
        return unknown('district', districtId)
    end
    return copy(Replication.GetDistrictState(id))
end

local function getTransformerState(transformerId)
    local id, err = validateRegistryId(Transformers, 'transformer', transformerId)
    if not id then return nil, err end
    return copy(TransformerManager.GetState(id))
end

local function getSubstationState(substationId)
    local id, err = validateRegistryId(Substations, 'substation', substationId)
    if not id then return nil, err end
    return copy(SubstationManager.GetState(id))
end

local function getActiveIncident(gridId)
    local id, err = validateRegistryId(Grids, 'grid', gridId)
    if not id then return nil, err end
    return copy(IncidentManager.GetActiveIncidentForGrid(id))
end

local function getIncident(incidentId)
    local id = ApiHelpers.NormalizeIdentifier(incidentId)
    if not id then return unknown('incident', incidentId) end
    local incident = IncidentManager.GetIncident(id)
    if not incident then return unknown('incident', id) end
    return copy(incident)
end

function InfrastructureApi.GetFeederState(feederId)
    local id, err = validateRegistryId(Feeders, 'feeder', feederId)
    if not id then return nil, err end

    local state = FeederManager.GetState(id)
    if not state then return nil, ('state unavailable for feeder "%s"'):format(id) end

    local result = copy(state)
    result.districts = copy(Feeders[id].districts or {})
    result.transformerIds = copy(GridManager.GetTransformersForFeeder(id))
    return result
end

function InfrastructureApi.IsFeederPowered(feederId)
    local state, err = InfrastructureApi.GetFeederState(feederId)
    if not state then return nil, err end
    return state.powered == true
end

function InfrastructureApi.IsSubstationPowered(substationId)
    local state, err = getSubstationState(substationId)
    if not state then return nil, err end
    return state.powered == true
end

function InfrastructureApi.GetPowerPathForDistrict(districtId)
    local id = ApiHelpers.NormalizeDistrict(districtId)
    if not id or not Districts.Exists(id) then
        return unknown('district', districtId)
    end

    local gridId = GridManager.GetGridForDistrict(id)
    if not gridId then
        return unassignedPath(nil, id)
    end

    return copy(buildPowerPath(id, gridId))
end

function InfrastructureApi.GetInfrastructureAtPosition(coords)
    local valid, err = ApiHelpers.ValidateCoordinates(coords)
    if not valid then return nil, err end

    local copiedCoords = ApiHelpers.CopyCoordinates(coords)
    local resolvedGrid, resolvedDistrict = ServerZone.ResolvePosition(coords)
    local district = ServerZone.ResolveDistrictOnly(coords) or resolvedDistrict

    if resolvedGrid and Grids[resolvedGrid] then
        local assignedGrid = district and GridManager.GetGridForDistrict(district) or nil
        local path = buildPowerPath(
            assignedGrid == resolvedGrid and district or nil,
            resolvedGrid
        )
        path.coords = copiedCoords
        path.district = district
        return copy(path)
    end

    -- A known GTA district without a topology assignment remains explicitly
    -- unmanaged and fail-open; an unmapped coordinate uses the same shape
    -- with district=nil so callers never need a special error path.
    return copy(unassignedPath(copiedCoords, district))
end

function InfrastructureApi.GetAffectedDistricts(targetType, targetId)
    local normalizedType = ApiHelpers.NormalizeIdentifier(targetType)
    if normalizedType then normalizedType = string.lower(normalizedType) end
    local impact, err = IncidentImpact.Calculate(normalizedType, targetId)
    if not impact then return nil, err end
    return copy(impact.affectedDistricts or {})
end

function InfrastructureApi.GetActiveIncidents()
    return copy(IncidentManager.GetAllActiveIncidents())
end

-- Existing public surface.  Return values remain compatible while all table
-- results now satisfy the Phase 24 detached-copy contract.
InfrastructureApi.IsGridPowered = isGridPowered
InfrastructureApi.IsDistrictPowered = isDistrictPowered
InfrastructureApi.IsPositionPowered = isPositionPowered
InfrastructureApi.GetGridState = getPublishedGridState
InfrastructureApi.GetDistrictState = getPublishedDistrictState
InfrastructureApi.GetTransformerState = getTransformerState
InfrastructureApi.GetSubstationState = getSubstationState
InfrastructureApi.GetActiveIncident = getActiveIncident
InfrastructureApi.GetIncident = getIncident
InfrastructureApi.GetAllActiveIncidents = InfrastructureApi.GetActiveIncidents

exports('IsGridPowered', InfrastructureApi.IsGridPowered)
exports('IsDistrictPowered', InfrastructureApi.IsDistrictPowered)
exports('IsPositionPowered', InfrastructureApi.IsPositionPowered)
exports('GetGridState', InfrastructureApi.GetGridState)
exports('GetDistrictState', InfrastructureApi.GetDistrictState)
exports('GetTransformerState', InfrastructureApi.GetTransformerState)
exports('GetSubstationState', InfrastructureApi.GetSubstationState)
exports('IsSubstationPowered', InfrastructureApi.IsSubstationPowered)
exports('IsFeederPowered', InfrastructureApi.IsFeederPowered)
exports('GetFeederState', InfrastructureApi.GetFeederState)
exports('GetInfrastructureAtPosition', InfrastructureApi.GetInfrastructureAtPosition)
exports('GetPowerPathForDistrict', InfrastructureApi.GetPowerPathForDistrict)
exports('GetAffectedDistricts', InfrastructureApi.GetAffectedDistricts)
exports('GetActiveIncident', InfrastructureApi.GetActiveIncident)
exports('GetIncident', InfrastructureApi.GetIncident)
exports('GetActiveIncidents', InfrastructureApi.GetActiveIncidents)
exports('GetAllActiveIncidents', InfrastructureApi.GetAllActiveIncidents)
