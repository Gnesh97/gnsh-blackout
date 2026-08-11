--[[
    server/dispatch.lua

    Optional dispatch bridge for Phase 23. The resource never hard-depends on
    a dispatch script. Every incident is emitted on the stable internal
    `infra:dispatchIncident` event; a configured external resource/event is
    an additional adapter, not a requirement for incident lifecycle.
]]

DispatchBridge = {}

function DispatchBridge.BuildPayload(incident)
    local metadata = incident.metadata or {}
    local impact = incident.estimatedImpact or metadata.estimatedImpact or {}
    local affectedDistricts = incident.affectedDistricts
        or metadata.affectedDistricts
        or incident.districts
        or {}

    return {
        incidentId = incident.incidentId,
        status = incident.status,
        cause = incident.cause,
        severity = incident.severity,
        targetType = incident.targetType or metadata.targetType,
        targetId = incident.targetId or metadata.targetId,
        gridId = incident.gridId,
        substationId = incident.substationId,
        feederId = incident.feederId or metadata.feederId,
        transformerId = incident.transformerId,
        affectedDistricts = Utils.ShallowCopy(affectedDistricts),
        affectedDistrictCount = impact.districtCount or #affectedDistricts,
        playerCount = impact.playerCount or 0,
        estimatedImpact = Utils.ShallowCopy(impact),
        approximateLocation = incident.approximateLocation or metadata.approximateLocation,
        startedBy = incident.startedBy,
        startedAt = incident.startedAt,
        completedAt = incident.completedAt,
    }
end

function DispatchBridge.Publish(incident)
    local payload = DispatchBridge.BuildPayload(incident)
    local config = Config.Dispatch or {}

    if config.emitInternalEvent ~= false then
        TriggerEvent('infra:dispatchIncident', payload)
    end

    if not config.enabled or not config.resource or not config.serverEvent then
        return false, 'dispatch adapter not configured'
    end

    if GetResourceState(config.resource) ~= 'started' then
        return false, ('dispatch resource "%s" is not started'):format(config.resource)
    end

    local ok, err = pcall(TriggerEvent, config.serverEvent, payload)
    if not ok and Log then
        Log.warn('dispatch adapter failed', { resource = config.resource, error = tostring(err) })
    end
    return ok, err
end

