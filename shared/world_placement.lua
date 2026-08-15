--[[
    shared/world_placement.lua

    Phase 22 world placement registry (spec §22).

    Topology keeps logical relationships; this registry owns physical
    placement. Network entity ids are intentionally absent. `model` is an
    optional expected map model used by client-side validation, never an
    identity and never an instruction to spawn a prop.

    Logical-only topology entries are retained in this registry with
    physical=false and enabled=false when no verified world placement exists.
    They remain available to server topology, incidents, API and admin
    operations without creating fake interaction coordinates.
]]

InfrastructureWorld = {}

-- Current coordinates are intentionally still marked as placeholders. They
-- are now kept in one physical source of truth so Phase 22 validation can
-- replace them without touching logical topology ids or runtime state.
local placements = {
    sandy_substation_01 = {
        coords = vector3(1961.0, 3740.0, 32.2),
        heading = 0.0,
        interactionRadius = 8.0,
        visualRadius = 15.0,
    },
    sandy_tr_01 = {
        coords = vector3(1961.0, 3745.0, 32.2),
        heading = 0.0,
        model = 'prop_generator_01b',
        interactionRadius = 6.0,
        visualRadius = 15.0,
    },
    blaine_south_tr_02 = {
        coords = vector3(1975.0, 3745.0, 32.2),
        heading = 0.0,
        model = 'prop_generator_01b',
        interactionRadius = 6.0,
        visualRadius = 15.0,
    },
    ls_central_substation_01 = {
        coords = vector3(-190.0, -620.0, 33.0),
        heading = 0.0,
        interactionRadius = 8.0,
        visualRadius = 15.0,
    },
    ls_central_tr_01 = {
        coords = vector3(-195.0, -615.0, 33.0),
        heading = 0.0,
        model = 'prop_generator_01b',
        interactionRadius = 6.0,
        visualRadius = 15.0,
    },
}

local function appendUnique(list, seen, value)
    if value and not seen[value] then
        seen[value] = true
        list[#list + 1] = value
    end
end

local function findGridForSubstation(substationId)
    local substation = Substations[substationId]
    return substation and substation.gridId or nil
end

local function findFeederForTransformer(transformerId)
    for feederId, feeder in pairs(Feeders or {}) do
        for _, candidateId in ipairs(feeder.transformers or {}) do
            if candidateId == transformerId then
                return feederId, feeder
            end
        end
    end
    return nil, nil
end

local function districtsForSubstation(substationId, gridId)
    local districts, seen = {}, {}

    for _, feeder in pairs(Feeders or {}) do
        if feeder.substationId == substationId then
            for _, district in ipairs(feeder.districts or {}) do
                appendUnique(districts, seen, district)
            end
        end
    end

    if #districts == 0 and Grids[gridId] then
        for _, district in ipairs(Grids[gridId].districts or {}) do
            appendUnique(districts, seen, district)
        end
    end

    table.sort(districts)
    return districts
end

for substationId, substation in pairs(Substations) do
    local gridId = findGridForSubstation(substationId)
    local placement = placements[substationId] or {}
    local physical = placement.physical == true
        or (placement.physical == nil and substation.physical ~= false and placement.coords ~= nil)

    InfrastructureWorld[substationId] = {
        logicalId = substationId,
        type = 'substation',
        gridId = gridId,
        substationId = substationId,
        feederId = nil,
        coords = physical and placement.coords or nil,
        heading = placement.heading or 0.0,
        model = physical and placement.model or nil,
        interactionRadius = placement.interactionRadius or 8.0,
        visualRadius = placement.visualRadius or 15.0,
        physical = physical,
        enabled = physical and placement.enabled ~= false or false,
        expectedDistricts = districtsForSubstation(substationId, gridId),
    }
end

for transformerId, transformer in pairs(Transformers) do
    local substationId = transformer.substationId
    local gridId = findGridForSubstation(substationId)
    local feederId, feeder = findFeederForTransformer(transformerId)
    local placement = placements[transformerId] or {}
    local physical = placement.physical == true
        or (placement.physical == nil and transformer.physical ~= false and placement.coords ~= nil)
    local expectedDistricts = {}

    if feeder then
        for _, district in ipairs(feeder.districts or {}) do
            expectedDistricts[#expectedDistricts + 1] = district
        end
    elseif Grids[gridId] then
        for _, district in ipairs(Grids[gridId].districts or {}) do
            expectedDistricts[#expectedDistricts + 1] = district
        end
    end

    table.sort(expectedDistricts)

    InfrastructureWorld[transformerId] = {
        logicalId = transformerId,
        type = 'transformer',
        gridId = gridId,
        substationId = substationId,
        feederId = feederId,
        coords = physical and placement.coords or nil,
        heading = placement.heading or 0.0,
        model = physical and placement.model or nil,
        interactionRadius = placement.interactionRadius or 6.0,
        visualRadius = placement.visualRadius or 15.0,
        physical = physical,
        enabled = physical and placement.enabled ~= false or false,
        expectedDistricts = expectedDistricts,
    }
end

Utils.FreezeShape(InfrastructureWorld)
