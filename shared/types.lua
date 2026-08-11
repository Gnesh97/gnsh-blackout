--[[
    shared/types.lua

    Struct factories for the framework's core data shapes. Field names are
    chosen to line up 1:1 with the eventual `infrastructure_transformers` /
    `infrastructure_incidents` DB columns from spec §45 (camelCase here,
    snake_case in SQL — Phase 14 maps between them) so persistence doesn't
    require renaming fields later (RULE 9: don't break the shape).

    These are plain-table factories, not classes — the framework favours
    small pure functions (power_calculator, utilities) over OOP, and structs
    are cheap to copy/replicate as-is into StateBags.
]]

Types = {}

-- A transformer's mutable runtime record (spec §13, §45).
-- Static definition (coords, model, substationId, primary flag, capacity)
-- lives in shared/grids.lua — this factory only carries the mutable part
-- server/transformer_manager.lua tracks per transformer id.
function Types.NewTransformer(id, overrides)
    local t = {
        id = id,
        state = Constants.TransformerState.ONLINE,
        condition = Constants.Condition.HEALTHY,
        damage = 0,
        lastFailure = nil,
        lastRepair = nil,
        updatedAt = nil,
        revision = 0,
    }
    if overrides then
        for k, v in pairs(overrides) do t[k] = v end
    end
    return t
end

-- Replicated grid power state (spec §16, §19).
function Types.NewGridState(gridId, overrides)
    local g = {
        gridId = gridId,
        powered = true,
        level = 1.0,
        status = Constants.GridStatus.ONLINE,
        revision = 0,
        forcedOffline = false,
        blockedBy = nil,
    }
    if overrides then
        for k, v in pairs(overrides) do g[k] = v end
    end
    return g
end

-- Replicated district power state (spec §19). `level`/`status` added
-- Phase 18 — before the feeder layer, a district's state was a straight
-- copy of its grid's, so only `powered`/`revision` mattered; now it's
-- independently computed from whichever feeders actually supply it (see
-- PowerCalculator.CalculateDistrict), so it needs the same level/status
-- shape a grid state carries.
function Types.NewDistrictState(district, overrides)
    local d = {
        district = district,
        gridId = nil,
        feederIds = {},
        sourceFeederId = nil,
        powered = true,
        level = 1.0,
        status = Constants.GridStatus.ONLINE,
        revision = 0,
        blockedBy = nil,
    }
    if overrides then
        for k, v in pairs(overrides) do d[k] = v end
    end
    return d
end

-- Feeder is a distinct entity (spec §18.3) but its runtime state is always
-- DERIVED (like Substation's — server/substation_manager.lua), never
-- stored independently. This factory is only used for the REPLICATED
-- snapshot published to GlobalState (spec §19), not a persisted record.
function Types.NewFeederState(feederId, overrides)
    local f = {
        feederId = feederId,
        substationId = nil,
        powered = true,
        level = 1.0,
        status = Constants.GridStatus.ONLINE,
        revision = 0,
        forcedOffline = false,
        blockedBy = nil,
    }
    if overrides then
        for k, v in pairs(overrides) do f[k] = v end
    end
    return f
end

-- Incident record (spec §17, §45). Not persisted or created until Phase 11
-- — defined now so log/debug output and the GetActiveIncident() API stub
-- (Phase 7) have a stable shape to reference.
function Types.NewIncident(overrides)
    local inc = {
        incidentId = nil,
        targetType = nil,
        targetId = nil,
        gridId = nil,
        districts = {},
        affectedDistricts = {},
        estimatedImpact = { districtCount = 0, playerCount = 0 },
        approximateLocation = nil,
        substationId = nil,
        feederId = nil,
        transformerId = nil,
        cause = Constants.IncidentCause.UNKNOWN,
        severity = 'MINOR',
        status = Constants.IncidentStatus.ACTIVE,
        startedAt = nil,
        startedBy = nil,
        repairer = nil,
        completedAt = nil,
        metadata = {},
    }
    if overrides then
        for k, v in pairs(overrides) do inc[k] = v end
    end
    return inc
end
