--[[
    server/failure_manager.lua

    Server-authoritative operational overrides for parent infrastructure
    components (spec §21). A forced parent failure never mutates child
    transformer records; it only blocks effective power calculation until
    the parent is restored.
]]

FailureManager = {}

local overrides = {
    [Constants.ComponentType.GRID] = {},
    [Constants.ComponentType.SUBSTATION] = {},
    [Constants.ComponentType.FEEDER] = {},
    [Constants.ComponentType.DISTRICT] = {},
    [Constants.ComponentType.REGION] = {},
}

local function isSupportedType(targetType)
    return targetType == Constants.ComponentType.GRID
        or targetType == Constants.ComponentType.SUBSTATION
        or targetType == Constants.ComponentType.FEEDER
        or targetType == Constants.ComponentType.DISTRICT
        or targetType == Constants.ComponentType.REGION
end

local function targetExists(targetType, targetId)
    if targetType == Constants.ComponentType.GRID then return Grids[targetId] ~= nil end
    if targetType == Constants.ComponentType.SUBSTATION then return Substations[targetId] ~= nil end
    if targetType == Constants.ComponentType.FEEDER then return Feeders[targetId] ~= nil end
    if targetType == Constants.ComponentType.DISTRICT then return Districts.Exists(targetId) end
    if targetType == Constants.ComponentType.REGION then return PowerRegions.Get(targetId) ~= nil end
    return false
end

local function getOverride(targetType, targetId)
    local bucket = overrides[targetType]
    return bucket and bucket[targetId] or nil
end

local function blockRecord(targetType, targetId)
    return {
        type = targetType,
        id = targetId,
    }
end

local function recalculate(targetType, targetId, reason)
    if not Replication then return end

    if targetType == Constants.ComponentType.GRID then
        Replication.RecalculateForGrid(targetId, reason)
    elseif targetType == Constants.ComponentType.SUBSTATION then
        Replication.RecalculateForSubstation(targetId, reason)
    elseif targetType == Constants.ComponentType.FEEDER then
        Replication.RecalculateForFeeder(targetId, reason)
    elseif targetType == Constants.ComponentType.DISTRICT then
        Replication.RecalculateDistrict(targetId, reason)
    elseif targetType == Constants.ComponentType.REGION then
        local region = PowerRegions.Get(targetId)
        for _, districtCode in ipairs(region and region.districts or {}) do
            Replication.RecalculateDistrict(districtCode, reason)
        end
    end
end

local function createFailureIncident(targetType, targetId, reason, source, context)
    if not IncidentManager
        or targetType == Constants.ComponentType.DISTRICT
        or targetType == Constants.ComponentType.REGION then
        return
    end
    context = context or {}

    local ok, incidentIdOrRecord, err = pcall(IncidentManager.CreateIncident, {
        targetType = targetType,
        targetId = targetId,
        cause = context.cause or Constants.IncidentCause.ADMIN,
        severity = context.severity or 100,
        startedBy = source or reason or 'SYSTEM',
        metadata = {
            failureReason = reason or 'unspecified',
        },
    })

    if not ok then
        Log.warn('parent failure incident creation failed', {
            targetType = targetType,
            targetId = targetId,
            error = tostring(incidentIdOrRecord),
        })
    elseif not incidentIdOrRecord and err then
        Log.warn('parent failure incident rejected', {
            targetType = targetType,
            targetId = targetId,
            error = tostring(err),
        })
    end
end

local function resolveFailureIncident(targetType, targetId, reason, source)
    if not IncidentManager
        or targetType == Constants.ComponentType.DISTRICT
        or targetType == Constants.ComponentType.REGION
        or not IncidentManager.ResolveActiveIncidentForTarget then
        return
    end

    local ok, resolved, err = pcall(
        IncidentManager.ResolveActiveIncidentForTarget,
        targetType,
        targetId,
        source or reason or 'SYSTEM',
        { restoreReason = reason or 'restored' }
    )

    if not ok then
        Log.warn('parent failure incident resolve failed', {
            targetType = targetType,
            targetId = targetId,
            error = tostring(resolved),
        })
    elseif resolved == false and err ~= 'no active incident' then
        Log.warn('parent failure incident resolve rejected', {
            targetType = targetType,
            targetId = targetId,
            error = tostring(err),
        })
    end
end

local function validateTarget(targetType, targetId)
    if not isSupportedType(targetType) then
        return false, ('unsupported infrastructure target type "%s"'):format(tostring(targetType))
    end
    if type(targetId) ~= 'string' or targetId == '' then
        return false, 'infrastructure target id must be a non-empty string'
    end
    if not targetExists(targetType, targetId) then
        return false, ('unknown %s "%s"'):format(targetType, targetId)
    end
    return true
end

function FailureManager.GetState(targetType, targetId)
    local record = getOverride(targetType, targetId)
    return record and Utils.ShallowCopy(record) or nil
end

function FailureManager.IsBlocked(targetType, targetId)
    local record = getOverride(targetType, targetId)
    return record ~= nil and record.state == Constants.ComponentState.OFFLINE
end

-- Returns the first blocker in top-down hierarchy order. For transformer
-- lookup, transformer itself is deliberately not a supported override target;
-- its own operational state is owned by TransformerManager.
function FailureManager.GetBlockingAncestor(targetType, targetId)
    local candidates = {}

    if targetType == Constants.ComponentType.GRID then
        candidates[#candidates + 1] = { Constants.ComponentType.GRID, targetId }
    elseif targetType == Constants.ComponentType.SUBSTATION then
        candidates[#candidates + 1] = { Constants.ComponentType.GRID, GridManager.GetGridForSubstation(targetId) }
        candidates[#candidates + 1] = { Constants.ComponentType.SUBSTATION, targetId }
    elseif targetType == Constants.ComponentType.FEEDER then
        local substationId = GridManager.GetSubstationForFeeder(targetId)
        candidates[#candidates + 1] = { Constants.ComponentType.GRID, GridManager.GetGridForSubstation(substationId) }
        candidates[#candidates + 1] = { Constants.ComponentType.SUBSTATION, substationId }
        candidates[#candidates + 1] = { Constants.ComponentType.FEEDER, targetId }
    elseif targetType == Constants.ComponentType.TRANSFORMER then
        local substationId = GridManager.GetSubstationForTransformer(targetId)
        local feederId = GridManager.GetFeederForTransformer(targetId)
        candidates[#candidates + 1] = { Constants.ComponentType.GRID, GridManager.GetGridForSubstation(substationId) }
        candidates[#candidates + 1] = { Constants.ComponentType.SUBSTATION, substationId }
        candidates[#candidates + 1] = { Constants.ComponentType.FEEDER, feederId }
    elseif targetType == Constants.ComponentType.DISTRICT then
        candidates[#candidates + 1] = { Constants.ComponentType.DISTRICT, targetId }
        for _, region in ipairs(PowerRegions.GetRegionsForDistrict(targetId)) do
            candidates[#candidates + 1] = { Constants.ComponentType.REGION, region.id }
        end
    end

    for _, candidate in ipairs(candidates) do
        if candidate[2] and FailureManager.IsBlocked(candidate[1], candidate[2]) then
            return blockRecord(candidate[1], candidate[2])
        end
    end

    return nil
end

function FailureManager.SetState(targetType, targetId, state, reason, source, context)
    context = context or {}
    local valid, err = validateTarget(targetType, targetId)
    if not valid then
        Log.event(Constants.LogEvent.INFRASTRUCTURE_FAILURE_REJECTED, {
            targetType = targetType, targetId = targetId, state = state, reason = err, source = source,
        })
        return false, err
    end

    if state == Constants.ComponentState.ONLINE then
        return FailureManager.Restore(targetType, targetId, reason, source)
    end
    if state ~= Constants.ComponentState.OFFLINE then
        local invalidState = ('invalid infrastructure state "%s"'):format(tostring(state))
        Log.event(Constants.LogEvent.INFRASTRUCTURE_FAILURE_REJECTED, {
            targetType = targetType, targetId = targetId, state = state, reason = invalidState, source = source,
        })
        return false, invalidState
    end

    local existing = getOverride(targetType, targetId)
    if existing and existing.state == state then
        -- Retry the write on an idempotent command. This repairs persistence
        -- after a temporary DB/table failure without forcing a needless
        -- replication revision bump.
        if Persistence then Persistence.SaveOverride(existing) end
        createFailureIncident(targetType, targetId, reason, source, context)
        return true
    end

    local record = {
        componentType = targetType,
        componentId = targetId,
        type = targetType,
        id = targetId,
        state = state,
        reason = reason or 'unspecified',
        updatedBy = source,
        updatedAt = os.time(),
    }
    overrides[targetType][targetId] = record

    if Persistence then Persistence.SaveOverride(record) end
    Log.event(Constants.LogEvent.INFRASTRUCTURE_OFFLINE, {
        targetType = targetType, targetId = targetId, reason = reason, source = source,
    })
    recalculate(targetType, targetId, reason)
    createFailureIncident(targetType, targetId, reason, source, context)
    return true
end

function FailureManager.Restore(targetType, targetId, reason, source)
    local valid, err = validateTarget(targetType, targetId)
    if not valid then return false, err end

    if not getOverride(targetType, targetId) then
        -- Also reconcile a stale DB row when memory already considers the
        -- target online (for example after a previous delete failure).
        if Persistence then Persistence.DeleteOverride(targetType, targetId) end
        resolveFailureIncident(targetType, targetId, reason, source)
        return true
    end
    overrides[targetType][targetId] = nil

    if Persistence then Persistence.DeleteOverride(targetType, targetId) end
    Log.event(Constants.LogEvent.INFRASTRUCTURE_RESTORED, {
        targetType = targetType, targetId = targetId, reason = reason, source = source,
    })
    recalculate(targetType, targetId, reason)
    resolveFailureIncident(targetType, targetId, reason, source)
    return true
end

function FailureManager.GetAll()
    local result = {}
    for targetType, bucket in pairs(overrides) do
        for _, record in pairs(bucket) do
            result[#result + 1] = Utils.ShallowCopy(record)
        end
    end
    table.sort(result, function(a, b)
        if a.componentType == b.componentType then return a.componentId < b.componentId end
        return a.componentType < b.componentType
    end)
    return result
end

-- Boot-only restore. Invalid/stale rows are ignored and logged; restore must
-- not write back to SQL or recalculate before Replication.Init().
function FailureManager.RestoreAll(rows)
    -- boot() can be called again after a live script refresh. Clear the
    -- in-memory snapshot first so a removed DB row cannot survive that
    -- second boot as a phantom parent failure.
    for _, bucket in pairs(overrides) do
        for targetId in pairs(bucket) do
            bucket[targetId] = nil
        end
    end

    for _, row in ipairs(rows or {}) do
        local targetType = row.component_type or row.componentType
        local targetId = row.component_id or row.componentId
        local state = row.state
        local valid = isSupportedType(targetType) and targetExists(targetType, targetId)
        if valid and state == Constants.ComponentState.OFFLINE then
            overrides[targetType][targetId] = {
                componentType = targetType,
                componentId = targetId,
                type = targetType,
                id = targetId,
                state = state,
                reason = row.reason or 'restored',
                updatedBy = row.updated_by or row.updatedBy,
                updatedAt = row.updated_at or row.updatedAt,
            }
        else
            Log.warn('ignored invalid persisted infrastructure override', {
                targetType = targetType, targetId = targetId, state = state,
            })
        end
    end
end
