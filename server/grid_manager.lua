--[[
    server/grid_manager.lua

    Builds and serves reverse lookups over the static topology in
    shared/grids.lua and shared/feeders.lua (spec §11, §12, §18):
    district -> grid, transformer -> substation, substation -> grid,
    grid -> transformers, and (Phase 18) the feeder-layer equivalents —
    feeder -> substation, substation -> feeders, feeder -> transformers,
    transformer -> feeder, district -> feeders. Everything here is O(1)
    after GridManager.Init() runs once at startup — no table walking on
    the hot path (spec §58 performance principle).
]]

GridManager = {}

local districtToGrid = {}
local transformerToSubstation = {}
local substationToGrid = {}
local gridToTransformers = {}

-- Phase 18 feeder indices.
local feederToSubstation = {}
local substationToFeeders = {}
local feederToTransformers = {}
local transformerToFeeder = {}
local districtToFeeders = {}

local initialized = false

function GridManager.Init()
    districtToGrid = {}
    transformerToSubstation = {}
    substationToGrid = {}
    gridToTransformers = {}
    feederToSubstation = {}
    substationToFeeders = {}
    feederToTransformers = {}
    transformerToFeeder = {}
    districtToFeeders = {}

    for gridId, grid in pairs(Grids) do
        for _, code in ipairs(grid.districts) do
            districtToGrid[code] = gridId
        end

        local transformerIds = {}
        for _, subId in ipairs(grid.substations) do
            local sub = Substations[subId]
            if sub then
                substationToGrid[subId] = gridId
                for _, trId in ipairs(sub.transformers) do
                    transformerToSubstation[trId] = subId
                    transformerIds[#transformerIds + 1] = trId
                end
            end
        end
        gridToTransformers[gridId] = transformerIds
    end

    for feederId, feeder in pairs(Feeders or {}) do
        feederToSubstation[feederId] = feeder.substationId
        substationToFeeders[feeder.substationId] = substationToFeeders[feeder.substationId] or {}
        table.insert(substationToFeeders[feeder.substationId], feederId)

        local trIds = {}
        for _, trId in ipairs(feeder.transformers) do
            transformerToFeeder[trId] = feederId
            trIds[#trIds + 1] = trId
        end
        feederToTransformers[feederId] = trIds

        for _, code in ipairs(feeder.districts) do
            districtToFeeders[code] = districtToFeeders[code] or {}
            table.insert(districtToFeeders[code], feederId)
        end
    end

    initialized = true
    Log.event(Constants.LogEvent.RESOURCE_STARTED, {
        grids = Utils.TableCount(Grids),
        substations = Utils.TableCount(Substations),
        transformers = Utils.TableCount(Transformers),
        feeders = Utils.TableCount(Feeders or {}),
    })
end

function GridManager.IsInitialized()
    return initialized
end

function GridManager.GetGridForDistrict(district)
    return districtToGrid[district]
end

function GridManager.GetSubstationForTransformer(transformerId)
    return transformerToSubstation[transformerId]
end

function GridManager.GetGridForSubstation(substationId)
    return substationToGrid[substationId]
end

function GridManager.GetGridForTransformer(transformerId)
    local subId = transformerToSubstation[transformerId]
    return subId and substationToGrid[subId] or nil
end

-- Returns a fresh array copy — callers must not mutate the internal index.
function GridManager.GetTransformersForGrid(gridId)
    local list = gridToTransformers[gridId]
    return list and Utils.ShallowCopy(list) or {}
end

function GridManager.GetAllGridIds()
    local ids = {}
    for gridId in pairs(Grids) do
        ids[#ids + 1] = gridId
    end
    return ids
end

-- ── Phase 18 feeder-layer lookups ────────────────────────────────────────

function GridManager.GetFeederForTransformer(transformerId)
    return transformerToFeeder[transformerId]
end

function GridManager.GetSubstationForFeeder(feederId)
    return feederToSubstation[feederId]
end

-- Returns a fresh array copy — same "callers must not mutate" contract as
-- GetTransformersForGrid above.
function GridManager.GetFeedersForSubstation(substationId)
    local list = substationToFeeders[substationId]
    return list and Utils.ShallowCopy(list) or {}
end

function GridManager.GetTransformersForFeeder(feederId)
    local list = feederToTransformers[feederId]
    return list and Utils.ShallowCopy(list) or {}
end

-- A district CAN be fed by more than one feeder (spec §29.1 partial
-- recovery implies this is a legitimate shape even though today's static
-- topology only ever wires one feeder per district) — always returns an
-- array, empty if the district isn't fed by any feeder (the caller falls
-- back to grid-level power in that case, see server/replication.lua).
function GridManager.GetFeedersForDistrict(district)
    local list = districtToFeeders[district]
    return list and Utils.ShallowCopy(list) or {}
end

function GridManager.GetAllFeederIds()
    local ids = {}
    for feederId in pairs(Feeders or {}) do
        ids[#ids + 1] = feederId
    end
    return ids
end
