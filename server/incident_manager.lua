--[[
    server/incident_manager.lua

    Incident Lifecycle System (spec §17, §45, Phase 11).

    Tracks active and historical incidents (blackouts, sabotages, random
    failures). Every major failure or sabotage creates an incident record.

    Records are built via Types.NewIncident() (shared/types.lua) so the
    field names (`incidentId`, not `id`) match spec §45's DB column
    naming 1:1 — Phase 14 persistence maps these directly, no renaming.

    Lifecycle closes via IncidentManager.UpdateStatus(id, RESOLVED, ...),
    which server/transformer_manager.lua calls automatically whenever a
    transformer transitions back to ONLINE — without that hook this
    system is a one-way street (an incident created here would never be
    resolvable until Phase 13's repair flow existed).
]]

IncidentManager = {}

local activeIncidents = {}      -- [incidentId] = incident record (Types.NewIncident shape)
local gridActiveMap = {}        -- [gridId] = { [incidentId] = true, ... } (a grid can have >1 transformer)
local transformerActiveMap = {} -- [transformerId] = incidentId (one active incident per transformer, enforced below)
local targetActiveMap = {}      -- [targetType][targetId] = incidentId (Phase 23)
local incidentHistory = {}      -- bounded ring buffer of resolved/cancelled incidents, see Config.MaxIncidentHistory
local incidentCounter = 0

function IncidentManager.Init()
    activeIncidents = {}
    gridActiveMap = {}
    transformerActiveMap = {}
    targetActiveMap = {}
    incidentHistory = {}
    incidentCounter = 0
end

-- Seed the runtime id generator from persisted history before any new
-- incident can be created. This deliberately only raises the counter.
function IncidentManager.SetCounterAtLeast(value)
    local number = tonumber(value)
    if not number then return end

    number = math.floor(number)
    if number > incidentCounter then
        incidentCounter = number
    end
end

local function generateId()
    incidentCounter = incidentCounter + 1
    return ('INC-%06d'):format(incidentCounter)
end

local function activeTargetBucket(targetType)
    targetActiveMap[targetType] = targetActiveMap[targetType] or {}
    return targetActiveMap[targetType]
end

local function mergeImpactMetadata(base, impact)
    local metadata = {}
    for key, value in pairs(base or {}) do metadata[key] = value end

    metadata.targetType = metadata.targetType or impact.targetType
    metadata.targetId = metadata.targetId or impact.targetId
    metadata.feederId = metadata.feederId or impact.feederId
    metadata.affectedDistricts = metadata.affectedDistricts or impact.affectedDistricts
    metadata.estimatedImpact = metadata.estimatedImpact or impact.estimatedImpact
    metadata.approximateLocation = metadata.approximateLocation or impact.approximateLocation
    return metadata
end

local function copyList(value)
    return type(value) == 'table' and Utils.ShallowCopy(value) or {}
end

local function pushHistory(incident)
    incidentHistory[#incidentHistory + 1] = incident
    local cap = Config.MaxIncidentHistory or 200
    while #incidentHistory > cap do
        table.remove(incidentHistory, 1)
    end
end

function IncidentManager.CreateIncident(params)
    if not params then
        return nil, 'missing incident parameters'
    end

    -- Phase 11/12 callers only supplied transformerId. Keep that contract
    -- while allowing Phase 21/23 parent failures to target any component.
    local targetType = params.targetType
        or (params.transformerId and Constants.ComponentType.TRANSFORMER)
    local targetId = params.targetId or params.transformerId
    if not targetType or not targetId then
        return nil, 'missing required incident parameters (targetType, targetId)'
    end

    local impact, impactErr = IncidentImpact.Calculate(targetType, targetId)
    if not impact then return nil, impactErr end

    local targetBucket = activeTargetBucket(targetType)

    -- Exactly one active incident per topology target. A parent and a child
    -- can both have incidents at once; they are different target keys.
    if targetBucket[targetId] then
        return targetBucket[targetId], 'incident already active'
    end

    local gridId = params.gridId or impact.gridId
    local substationId = params.substationId or impact.substationId
    local feederId = params.feederId or impact.feederId
    local transformerId = params.transformerId or impact.transformerId
    local affectedDistricts = copyList(params.affectedDistricts or impact.affectedDistricts)
    local metadata = mergeImpactMetadata(params.metadata, impact)

    local incident = Types.NewIncident({
        incidentId = generateId(),
        targetType = targetType,
        targetId = targetId,
        gridId = gridId,
        districts = affectedDistricts,
        affectedDistricts = affectedDistricts,
        estimatedImpact = params.estimatedImpact or impact.estimatedImpact,
        approximateLocation = params.approximateLocation or impact.approximateLocation,
        substationId = substationId,
        feederId = feederId,
        transformerId = transformerId,
        cause = params.cause or Constants.IncidentCause.UNKNOWN,
        severity = params.severity or 100,
        status = Constants.IncidentStatus.ACTIVE,
        startedAt = os.time(),
        startedBy = params.startedBy or 'SYSTEM',
        metadata = metadata,
    })

    activeIncidents[incident.incidentId] = incident
    targetBucket[targetId] = incident.incidentId

    if gridId then
        gridActiveMap[gridId] = gridActiveMap[gridId] or {}
        gridActiveMap[gridId][incident.incidentId] = true
    end

    if transformerId then
        transformerActiveMap[transformerId] = incident.incidentId
    end

    Log.event(Constants.LogEvent.INCIDENT_CREATED, {
        incidentId = incident.incidentId,
        gridId = gridId,
        targetType = targetType,
        targetId = targetId,
        transformer = transformerId,
        feeder = feederId,
        affectedDistrictCount = (incident.estimatedImpact and incident.estimatedImpact.districtCount)
            or #incident.affectedDistricts,
        cause = incident.cause,
        startedBy = incident.startedBy,
    })

    TriggerEvent('infra:incidentCreated', incident)
    if Metrics then Metrics.Inc('server.networkEvent.broadcast') end
    TriggerClientEvent('infra:incidentCreated', -1, incident)

    if Persistence then
        Persistence.SaveIncident(incident)
    end

    if DispatchBridge then
        DispatchBridge.Publish(incident)
    end

    return incident.incidentId, nil
end

function IncidentManager.UpdateStatus(incidentId, newStatus, repairer, metadata)
    local incident = activeIncidents[incidentId]
    if not incident then
        return false, ('unknown active incident "%s"'):format(tostring(incidentId))
    end

    if not Constants.IncidentStatus[newStatus] then
        return false, ('invalid status "%s"'):format(tostring(newStatus))
    end

    local oldStatus = incident.status
    incident.status = newStatus

    if repairer then
        incident.repairer = repairer
    end

    if metadata then
        incident.metadata = incident.metadata or {}
        for k, v in pairs(metadata) do
            incident.metadata[k] = v
        end
    end

    if newStatus == Constants.IncidentStatus.RESOLVED or newStatus == Constants.IncidentStatus.CANCELLED then
        incident.completedAt = os.time()

        activeIncidents[incidentId] = nil

        local gridSet = gridActiveMap[incident.gridId]
        if gridSet then
            gridSet[incidentId] = nil
            if next(gridSet) == nil then
                gridActiveMap[incident.gridId] = nil
            end
        end

        if transformerActiveMap[incident.transformerId] == incidentId then
            transformerActiveMap[incident.transformerId] = nil
        end

        if incident.targetType and incident.targetId
            and targetActiveMap[incident.targetType]
            and targetActiveMap[incident.targetType][incident.targetId] == incidentId then
            targetActiveMap[incident.targetType][incident.targetId] = nil
        end

        pushHistory(incident)

        Log.event(Constants.LogEvent.INCIDENT_RESOLVED, {
            incidentId = incidentId,
            gridId = incident.gridId,
            status = newStatus,
            repairedBy = incident.repairer,
        })

        TriggerEvent('infra:incidentResolved', incident)
        TriggerClientEvent('infra:incidentResolved', -1, incident)
    else
        TriggerEvent('infra:incidentStatusChanged', incident, oldStatus)
        TriggerClientEvent('infra:incidentStatusChanged', -1, incident, oldStatus)
    end

    if Persistence then
        Persistence.UpdateIncident(incident)
    end

    if DispatchBridge then
        DispatchBridge.Publish(incident)
    end

    return true, nil
end

-- Restore a persisted incident at boot (Phase 14, spec §47). Inserts
-- directly into the active-incident tables — does NOT go through
-- CreateIncident, which would mint a NEW incidentId, re-INSERT a row
-- that already exists in SQL, and fire incidentCreated events on every
-- single restart.
function IncidentManager.RestoreIncident(incident)
    if not incident or not incident.incidentId then return false end

    incident.metadata = incident.metadata or {}
    incident.targetType = incident.targetType
        or incident.metadata.targetType
        or (incident.transformerId and Constants.ComponentType.TRANSFORMER)
    incident.targetId = incident.targetId
        or incident.metadata.targetId
        or incident.transformerId

    if incident.targetType and incident.targetId and IncidentImpact then
        local impact = IncidentImpact.Calculate(incident.targetType, incident.targetId)
        if impact then
            incident.gridId = incident.gridId or impact.gridId
            incident.substationId = incident.substationId or impact.substationId
            incident.feederId = incident.feederId or impact.feederId
            incident.transformerId = incident.transformerId or impact.transformerId
            incident.affectedDistricts = incident.affectedDistricts or impact.affectedDistricts
            incident.districts = incident.districts or incident.affectedDistricts
            incident.estimatedImpact = incident.estimatedImpact or impact.estimatedImpact
            incident.approximateLocation = incident.approximateLocation or impact.approximateLocation
            incident.metadata = mergeImpactMetadata(incident.metadata, impact)
        end
    end

    activeIncidents[incident.incidentId] = incident

    if incident.gridId then
        gridActiveMap[incident.gridId] = gridActiveMap[incident.gridId] or {}
        gridActiveMap[incident.gridId][incident.incidentId] = true
    end

    if incident.targetType and incident.targetId then
        activeTargetBucket(incident.targetType)[incident.targetId] = incident.incidentId
    end

    if incident.transformerId then
        transformerActiveMap[incident.transformerId] = incident.incidentId
    end

    -- Keep future generateId() calls from colliding with restored ids
    -- (format 'INC-%06d').
    IncidentManager.SetCounterAtLeast(tonumber(incident.incidentId:match('(%d+)$')))

    return true
end

function IncidentManager.GetIncident(incidentId)
    local incident = activeIncidents[incidentId]
    if incident then return Utils.ShallowCopy(incident) end

    for _, inc in ipairs(incidentHistory) do
        if inc.incidentId == incidentId then
            return Utils.ShallowCopy(inc)
        end
    end
    return nil
end

-- A grid can have more than one transformer (and therefore more than one
-- simultaneous active incident) — this picks the most severe one
-- (tie-break: the one that started earliest) as "the" active incident for
-- callers using the singular GetActiveIncident(gridId) API (spec §48).
function IncidentManager.GetActiveIncidentForGrid(gridId)
    local set = gridActiveMap[gridId]
    if not set then return nil end

    local best = nil
    for incidentId in pairs(set) do
        local inc = activeIncidents[incidentId]
        if inc then
            if not best
                or inc.severity > best.severity
                or (inc.severity == best.severity and inc.startedAt < best.startedAt) then
                best = inc
            end
        end
    end

    return best and Utils.ShallowCopy(best) or nil
end

function IncidentManager.GetActiveIncidentForTransformer(transformerId)
    local incId = transformerActiveMap[transformerId]
    return incId and activeIncidents[incId] and Utils.ShallowCopy(activeIncidents[incId]) or nil
end

function IncidentManager.GetActiveIncidentForTarget(targetType, targetId)
    local bucket = targetActiveMap[targetType]
    local incidentId = bucket and bucket[targetId]
    return incidentId and activeIncidents[incidentId]
        and Utils.ShallowCopy(activeIncidents[incidentId]) or nil
end

function IncidentManager.ResolveActiveIncidentForTarget(targetType, targetId, repairer, metadata)
    local incident = IncidentManager.GetActiveIncidentForTarget(targetType, targetId)
    if not incident then return false, 'no active incident' end
    return IncidentManager.UpdateStatus(
        incident.incidentId,
        Constants.IncidentStatus.RESOLVED,
        repairer,
        metadata
    )
end

function IncidentManager.GetAllActiveIncidents()
    local list = {}
    for _, inc in pairs(activeIncidents) do
        list[#list + 1] = Utils.ShallowCopy(inc)
    end
    return list
end
