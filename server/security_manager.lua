--[[
    server/security_manager.lua

    Phase 26 server boundary guard. Every client-originated mutation keeps
    its domain validation in the owning manager, while this module provides
    the shared source, string, target, distance, session, revision, rate
    limit and ACE checks.
]]

Security = {}

local rateBuckets = {}
local txAdminAdmins = {}
local txAdminAuthRequests = {}

local function securityConfig()
    return Config.Security or {}
end

local function debugTxAdmin(message)
    if Config.Debug and Config.Debug.enabled then
        print('[gnsh-blackout] ' .. message)
    end
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

local function normalizeTxAdminSource(value)
    local numeric = tonumber(value)
    if not numeric or numeric <= 0 or math.floor(numeric) ~= numeric then
        return nil
    end
    return numeric
end

-- txAdmin emits this as a server-local event after authenticating a player.
-- Keep the handler local-only: registering it as a network event would allow
-- a client to forge its own admin status.
function Security.HandleTxAdminAuth(data)
    if type(data) ~= 'table' then return false end

    if type(data.isAdmin) ~= 'boolean' then return false end

    local rawNetid = tonumber(data.netid)
    if rawNetid == -1 then
        -- txAdmin uses -1 when forcing all online admins to reauthenticate.
        -- Never leave stale admin access alive across that boundary.
        if data.isAdmin then return false end
        txAdminAdmins = {}
        txAdminAuthRequests = {}
        debugTxAdmin('TXADMIN_AUTH_REVOKED_ALL')
        return true
    end

    local netid = normalizeTxAdminSource(rawNetid)
    if not netid then return false end

    txAdminAdmins[netid] = data.isAdmin
    debugTxAdmin(('TXADMIN_AUTH source=%d isAdmin=%s'):format(netid, tostring(data.isAdmin)))
    return true
end

-- txAdmin emits the currently authenticated admin NetIds when its admin list
-- changes. Build a replacement snapshot so removed admins lose access too.
function Security.HandleTxAdminAdminsUpdated(netids)
    if type(netids) ~= 'table' then return false end

    local updated = {}
    for key, value in pairs(netids) do
        local candidate = value
        if type(value) == 'boolean' then
            candidate = value and key or nil
        end

        local netid = normalizeTxAdminSource(candidate)
        if netid then
            updated[netid] = true
        end
    end

    txAdminAdmins = updated
    return true
end

function Security.IsTxAdminAdmin(source)
    if securityConfig().txAdmin ~= true then return false end
    local netid = normalizeTxAdminSource(source)
    return netid ~= nil and txAdminAdmins[netid] == true
end

function Security.RequestTxAdminAuth(source)
    if securityConfig().txAdmin ~= true or type(TriggerClientEvent) ~= 'function' then
        return false
    end

    local netid = normalizeTxAdminSource(source)
    if not netid then return false end

    local now = os.time()
    if txAdminAuthRequests[netid] and now - txAdminAuthRequests[netid] < 10 then
        return false
    end

    txAdminAuthRequests[netid] = now
    debugTxAdmin(('TXADMIN_AUTH_REQUESTED source=%d'):format(netid))
    TriggerClientEvent('gnsh-blackout:client:requestTxAdminAuth', netid)
    return true
end

-- These events are intentionally registered with AddEventHandler only.
-- FiveM's server-local txAdmin events do not become client-triggerable
-- network events this way.
if type(AddEventHandler) == 'function' then
    AddEventHandler('txAdmin:events:adminAuth', function(data)
        Security.HandleTxAdminAuth(data)
    end)
    AddEventHandler('txAdmin:events:adminsUpdated', function(netids)
        Security.HandleTxAdminAdminsUpdated(netids)
    end)
    AddEventHandler('playerDropped', function()
        local netid = normalizeTxAdminSource(source)
        if netid then
            txAdminAdmins[netid] = nil
            txAdminAuthRequests[netid] = nil
        end
    end)
end

local function hasCommandAceAdmin(source)
    local config = securityConfig()
    if config.allowCommandAceAdmins ~= true
        or type(IsPlayerAceAllowed) ~= 'function'
        or type(config.commandAcePermissions) ~= 'table' then
        return false
    end

    for _, permission in ipairs(config.commandAcePermissions) do
        if type(permission) == 'string' and permission ~= '' then
            local permissionOk, allowed = pcall(IsPlayerAceAllowed, source, permission)
            if permissionOk and allowed == true then
                return true
            end
        end
    end
    return false
end

function Security.RequireAdmin(source)
    if tonumber(source) == 0 then return true, 0 end
    local validSource, normalizedSource = Security.ValidateSource(source)
    if not validSource then return false, normalizedSource end
    if Security.IsTxAdminAdmin(normalizedSource) then
        return true, normalizedSource
    end
    local permissionOk, allowed = pcall(Bridge.HasPermission, normalizedSource, Config.Debug.adminGroup)
    if permissionOk and allowed == true then
        return true, normalizedSource
    end

    -- FXServer operators may have only command-specific ACE grants (for
    -- example command.refresh and command.restart), not the parent command
    -- ACE. Check the configured server-side permissions so resource admin
    -- commands follow the same authority that already controls those tools.
    if hasCommandAceAdmin(normalizedSource) then
        return true, normalizedSource
    end

    Security.RequestTxAdminAuth(normalizedSource)
    return reject('UNAUTHORIZED_ADMIN', 'admin permission required', { source = normalizedSource })
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
    txAdminAdmins = {}
    txAdminAuthRequests = {}
end
