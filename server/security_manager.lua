--[[
    server/security_manager.lua

    Phase 26 server boundary guard. Every client-originated mutation keeps
    its domain validation in the owning manager, while this module provides
    the shared source, string, target, distance, session, revision, rate
    limit and ACE checks.
]]

Security = {}

local rateBuckets = {}

local function securityConfig()
    return Config.Security or {}
end

local function reject(code, message, details)
    if Log and Log.event and Constants and Constants.LogEvent then
        Log.event(Constants.LogEvent.SECURITY_REJECTED, {
            code = code,
            message = message,
            details = details,
        })
    end
    return false, message or code
end

local function finiteNumber(value)
    return type(value) == 'number' and value == value and value < math.huge and value > -math.huge
end

local function nativePlayerPresent(source)
    if source == 0 then return true end
    local pingOk, ping = pcall(GetPlayerPing, source)
    if not pingOk or tonumber(ping) == nil or tonumber(ping) <= 0 then return false end

    local pedOk, ped = pcall(GetPlayerPed, source)
    return pedOk and ped and ped ~= 0
end

function Security.ValidateSource(source)
    local numeric = tonumber(source)
    if not numeric or numeric <= 0 or math.floor(numeric) ~= numeric then
        return reject('INVALID_SOURCE', 'invalid player source', { source = source })
    end
    if not nativePlayerPresent(numeric) then
        return reject('PLAYER_NOT_PRESENT', 'player is not currently connected', { source = numeric })
    end
    return true, numeric
end

function Security.ValidateString(value, fieldName)
    local name = fieldName or 'value'
    local maxLength = tonumber(securityConfig().maxStringLength) or 64
    if type(value) ~= 'string' or value == '' then
        return reject('INVALID_STRING', name .. ' must be a non-empty string', { field = name })
    end
    if #value > maxLength then
        return reject('STRING_TOO_LONG', name .. ' exceeds the maximum length', { field = name })
    end
    return true, value
end

function Security.ValidateEnum(value, allowed, fieldName)
    local validString, normalized = Security.ValidateString(value, fieldName)
    if not validString then return false, normalized end
    if type(allowed) ~= 'table' or not allowed[normalized] then
        return reject('INVALID_ENUM', (fieldName or 'value') .. ' is not an allowed value', { value = normalized })
    end
    return true, normalized
end

local function targetExists(targetType, targetId)
    if targetType == Constants.ComponentType.GRID then
        return Grids and Grids[targetId] ~= nil
    elseif targetType == Constants.ComponentType.SUBSTATION then
        return Substations and Substations[targetId] ~= nil
    elseif targetType == Constants.ComponentType.FEEDER then
        return Feeders and Feeders[targetId] ~= nil
    elseif targetType == Constants.ComponentType.TRANSFORMER then
        return Transformers and Transformers[targetId] ~= nil
    end
    return false
end

function Security.ValidateTarget(targetType, targetId)
    local allowedTypes = {
        [Constants.ComponentType.GRID] = true,
        [Constants.ComponentType.SUBSTATION] = true,
        [Constants.ComponentType.FEEDER] = true,
        [Constants.ComponentType.TRANSFORMER] = true,
    }
    local validType, normalizedType = Security.ValidateEnum(targetType, allowedTypes, 'targetType')
    if not validType then return false, normalizedType end

    local validId, normalizedId = Security.ValidateString(targetId, 'targetId')
    if not validId then return false, normalizedId end
    if not targetExists(normalizedType, normalizedId) then
        return reject('UNKNOWN_TARGET', 'unknown infrastructure target', {
            targetType = normalizedType,
            targetId = normalizedId,
        })
    end
    return true, normalizedType, normalizedId
end

function Security.ValidateDistance(source, coords, maxDistance)
    local validSource, normalizedSource = Security.ValidateSource(source)
    if not validSource then return false, normalizedSource end
    -- FiveM vector3 values are not guaranteed to report Lua type `table`
    -- (runtime commonly reports `vector3`/`userdata`). World placement uses
    -- vector3, so rejecting non-table coordinates breaks every repair stage
    -- completion even when the player is standing on the target.
    local coordsType = type(coords)
    local supportedCoords = coordsType == 'table'
        or coordsType == 'vector3'
        or coordsType == 'vector4'
        or coordsType == 'userdata'
    if not supportedCoords or not finiteNumber(coords.x) or not finiteNumber(coords.y) or not finiteNumber(coords.z) then
        return reject('INVALID_COORDINATES', 'target coordinates are invalid')
    end
    if not finiteNumber(maxDistance) or maxDistance < 0 then
        return reject('INVALID_DISTANCE_LIMIT', 'distance limit is invalid')
    end

    local pedOk, ped = pcall(GetPlayerPed, normalizedSource)
    if not pedOk or not ped or ped == 0 then
        return reject('PLAYER_PED_UNAVAILABLE', 'player ped is unavailable', { source = normalizedSource })
    end
    local coordsOk, playerCoords = pcall(GetEntityCoords, ped)
    if not coordsOk or not playerCoords then
        return reject('PLAYER_COORDINATES_UNAVAILABLE', 'player coordinates are unavailable', { source = normalizedSource })
    end

    local distanceOk, distance = pcall(Utils.Distance3D, playerCoords, coords)
    if not distanceOk or not finiteNumber(distance) or distance > maxDistance then
        return reject('OUT_OF_RANGE', 'player is too far from target', {
            source = normalizedSource,
            distance = distanceOk and distance or nil,
            maxDistance = maxDistance,
        })
    end
    return true, distance
end

function Security.AllowEvent(source, eventName, limit, windowSec)
    local validSource, normalizedSource = Security.ValidateSource(source)
    if not validSource then return false, normalizedSource end
    local validEvent, normalizedEvent = Security.ValidateString(eventName, 'eventName')
    if not validEvent then return false, normalizedEvent end

    local config = securityConfig()
    if config.enabled == false then return true, normalizedSource end

    local now = os.time()
    local window = tonumber(windowSec) or tonumber(config.rateWindowSec) or 10
    local maxEvents = tonumber(limit) or tonumber(config.maxEventsPerWindow) or 20
    rateBuckets[normalizedSource] = rateBuckets[normalizedSource] or {}
    local bucket = rateBuckets[normalizedSource][normalizedEvent]
    if not bucket or now - bucket.startedAt >= window then
        bucket = { startedAt = now, count = 0 }
        rateBuckets[normalizedSource][normalizedEvent] = bucket
    end

    bucket.count = bucket.count + 1
    if bucket.count > maxEvents then
        if Log and Log.event and Constants and Constants.LogEvent then
            Log.event(Constants.LogEvent.SECURITY_RATE_LIMITED, {
                source = normalizedSource,
                event = normalizedEvent,
                count = bucket.count,
                windowSec = window,
            })
        end
        return reject('RATE_LIMITED', 'event rate limit exceeded', { source = normalizedSource, event = normalizedEvent })
    end
    return true, normalizedSource
end

function Security.RequireAdmin(source)
    if tonumber(source) == 0 then return true, 0 end
    local validSource, normalizedSource = Security.ValidateSource(source)
    if not validSource then return false, normalizedSource end
    local permissionOk, allowed = pcall(Bridge.HasPermission, normalizedSource, Config.Debug.adminGroup)
    if not permissionOk or not allowed then
        return reject('UNAUTHORIZED_ADMIN', 'admin permission required', { source = normalizedSource })
    end
    return true, normalizedSource
end

local function stateForTarget(targetType, targetId)
    if targetType == Constants.ComponentType.TRANSFORMER and TransformerManager then
        return TransformerManager.GetState(targetId)
    elseif targetType == Constants.ComponentType.FEEDER and FeederManager then
        return FeederManager.GetState(targetId)
    elseif targetType == Constants.ComponentType.SUBSTATION and SubstationManager then
        return SubstationManager.GetState(targetId)
    elseif targetType == Constants.ComponentType.GRID and Replication then
        return Replication.GetGridState(targetId)
    end
    return nil
end

function Security.GetTargetRevision(targetType, targetId)
    local state = stateForTarget(targetType, targetId)
    if not state then return nil end
    return state.revision or state.updatedAt or state.lastFailure or state.lastRepair
end

function Security.ValidateRevision(targetType, targetId, expectedRevision)
    if expectedRevision == nil then return true end
    if not finiteNumber(expectedRevision) then
        return reject('INVALID_REVISION', 'revision must be numeric', { targetType = targetType, targetId = targetId })
    end
    local currentRevision = Security.GetTargetRevision(targetType, targetId)
    if currentRevision ~= nil and currentRevision ~= expectedRevision then
        return reject('STALE_REVISION', 'target revision is stale', {
            targetType = targetType,
            targetId = targetId,
            expectedRevision = expectedRevision,
            currentRevision = currentRevision,
        })
    end
    return true
end

function Security.ValidateSession(source, sessionId, action, targetType, targetId)
    local validSource, normalizedSource = Security.ValidateSource(source)
    if not validSource then return false, normalizedSource end
    local validSession, normalizedSession = Security.ValidateString(sessionId, 'sessionId')
    if not validSession then return false, normalizedSession end
    if not InteractionManager or not InteractionManager.GetSession then
        return reject('SESSION_MANAGER_UNAVAILABLE', 'interaction session manager unavailable')
    end

    local session = InteractionManager.GetSession(normalizedSource, normalizedSession)
    if not session then
        return reject('INVALID_SESSION', 'invalid or expired interaction session', { source = normalizedSource })
    end
    if action and session.action ~= action then
        return reject('SESSION_ACTION_MISMATCH', 'interaction action mismatch', { sessionId = normalizedSession })
    end
    if targetType and session.targetType and session.targetType ~= targetType then
        return reject('SESSION_TARGET_TYPE_MISMATCH', 'interaction target type mismatch', { sessionId = normalizedSession })
    end
    if targetId and session.targetId ~= targetId then
        return reject('SESSION_TARGET_MISMATCH', 'interaction target mismatch', { sessionId = normalizedSession })
    end
    return true, session
end

function Security.ResetForTests()
    rateBuckets = {}
end
