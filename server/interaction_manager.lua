--[[
    server/interaction_manager.lua

    Secure Interaction Session System (spec §35, §36, §40).

    Replaces simple un-validated client events with timed, nonced interaction
    sessions. Prevents event spoofing, minigame speedhacks, and race conditions
    where multiple players interact with the same target simultaneously.
]]

InteractionManager = {}

local activeSessions = {}  -- [sessionId] = sessionTable
local playerSessions = {}  -- [source] = sessionId
local targetLocks = {}     -- [targetId] = source
local sessionCounter = 0

local function generateSessionId()
    sessionCounter = sessionCounter + 1
    return ('SESS-%d-%d'):format(os.time(), sessionCounter)
end

function InteractionManager.StartSession(source, action, targetId, minDurationSec, maxTimeoutSec, metadata)
    source = tonumber(source)
    if not source or source <= 0 then
        return nil, 'invalid player source'
    end

    if not action or not targetId then
        return nil, 'missing action or targetId'
    end

    -- Check if player already has an active session
    if playerSessions[source] then
        local existingId = playerSessions[source]
        local sess = activeSessions[existingId]
        if sess and os.time() < sess.expiresAt then
            return nil, 'player already in an active interaction session'
        else
            -- Expired session, cleanup
            InteractionManager.CancelSession(source, existingId)
        end
    end

    -- Check target lock (prevent multiple players interacting with same transformer simultaneously)
    if targetLocks[targetId] and targetLocks[targetId] ~= source then
        local lockHolder = targetLocks[targetId]
        if GetPlayerPing(lockHolder) > 0 then
            return nil, 'target is currently locked by another player'
        else
            -- Stale lock from disconnected player
            targetLocks[targetId] = nil
        end
    end

    minDurationSec = minDurationSec or 3
    maxTimeoutSec = maxTimeoutSec or 60
    metadata = metadata or {}
    local maxSecurityTtl = Config.Security and tonumber(Config.Security.maxSessionTtlSec)
    if maxSecurityTtl and maxTimeoutSec > maxSecurityTtl then
        maxTimeoutSec = maxSecurityTtl
    end

    local sessionId = generateSessionId()
    local now = os.time()
    local session = {
        sessionId = sessionId,
        source = source,
        action = action,
        targetId = targetId,
        issuedAt = now,
        minDuration = minDurationSec,
        expiresAt = now + maxTimeoutSec,
        completed = false,
        targetType = metadata.targetType,
        targetRevision = metadata.targetRevision,
        expectedStage = metadata.expectedStage,
    }

    activeSessions[sessionId] = session
    playerSessions[source] = sessionId
    targetLocks[targetId] = source

    Log.event(Constants.LogEvent.INTERACTION_CREATED, {
        sessionId = sessionId,
        player = source,
        action = action,
        target = targetId,
    })

    return sessionId, nil
end

function InteractionManager.GetSession(source, sessionId)
    source = tonumber(source)
    local session = activeSessions[sessionId]
    if not session or session.source ~= source or session.completed then
        return nil
    end
    if os.time() > session.expiresAt then
        InteractionManager.CancelSession(source, sessionId)
        return nil
    end
    return session
end

function InteractionManager.ValidateSessionComplete(source, sessionId)
    source = tonumber(source)
    local session = activeSessions[sessionId]

    if not session then
        return false, 'invalid or expired session ID'
    end

    if session.source ~= source then
        return false, 'session ownership mismatch'
    end

    if session.completed then
        return false, 'session already completed'
    end

    local now = os.time()
    if now > session.expiresAt then
        InteractionManager.CancelSession(source, sessionId)
        return false, 'interaction session timed out'
    end

    -- Anti-cheat / minigame speedhack check: minDuration must have elapsed
    if (now - session.issuedAt) < session.minDuration then
        InteractionManager.CancelSession(source, sessionId)
        return false, 'interaction completed too quickly (speedhack detected)'
    end

    -- Session validated successfully — mark completed & release locks
    session.completed = true
    playerSessions[source] = nil
    if targetLocks[session.targetId] == source then
        targetLocks[session.targetId] = nil
    end
    activeSessions[sessionId] = nil

    return true, session
end

function InteractionManager.CancelSession(source, sessionId)
    source = tonumber(source)
    local session = activeSessions[sessionId]
    if session then
        if targetLocks[session.targetId] == session.source then
            targetLocks[session.targetId] = nil
        end
        playerSessions[session.source] = nil
        activeSessions[sessionId] = nil
    end
end

-- Cleanup locks on player drop
AddEventHandler('playerDropped', function()
    local src = source
    local sessId = playerSessions[src]
    if sessId then
        InteractionManager.CancelSession(src, sessId)
    end
end)
