--[[
    server/random_failure_manager.lua

    Server-only, impact-aware automatic failure scheduler (Phase 25).
    Runtime mutations always use existing transformer/parent failure managers
    so incident, persistence, replication, and recovery lifecycles stay in
    one place.
]]

RandomFailureManager = {}

local running = false
local schedulerGeneration = 0
local lastAutomaticFailureAt = nil
local lastFailureByTarget = {}

local defaultClock = function()
    return os.time()
end

local defaultRandomProvider = function(totalWeight)
    return math.random() * totalWeight
end

local defaultPlayerCountProvider = function()
    if type(GetPlayers) ~= 'function' then return 0 end

    local ok, players = pcall(GetPlayers)
    if not ok or type(players) ~= 'table' then return 0 end
    return #players
end

local clockProvider = defaultClock
local randomProvider = defaultRandomProvider
local playerCountProvider = defaultPlayerCountProvider

local conditionFactors = {
    [Constants.Condition.HEALTHY] = 1.0,
    [Constants.Condition.MINOR_DAMAGE] = 1.25,
    [Constants.Condition.MODERATE_DAMAGE] = 1.5,
    [Constants.Condition.MAJOR_DAMAGE] = 2.0,
    [Constants.Condition.CRITICAL_DAMAGE] = 3.0,
    [Constants.Condition.DESTROYED] = 0.0,
}

local targetDefinitions = {
    {
        targetType = Constants.ComponentType.FEEDER,
        weightKey = 'feederWeight',
        managerKey = 'FeederManager',
    },
    {
        targetType = Constants.ComponentType.SUBSTATION,
        weightKey = 'substationWeight',
        managerKey = 'SubstationManager',
    },
    {
        targetType = Constants.ComponentType.TRANSFORMER,
        weightKey = 'transformerWeight',
        managerKey = 'TransformerManager',
    },
}

local function safeLogWarning(message, data)
    if not Log or type(Log.warn) ~= 'function' then return end
    pcall(Log.warn, message, data)
end

local function clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function copyList(list)
    local result = {}
    for _, value in ipairs(list or {}) do
        result[#result + 1] = value
    end
    return result
end

local function targetKey(targetType, targetId)
    return ('%s:%s'):format(targetType, targetId)
end

local function safeCall(fn, ...)
    if type(fn) ~= 'function' then
        return false, 'dependency function unavailable'
    end

    local ok, first, second = pcall(fn, ...)
    if not ok then return false, tostring(first) end
    return true, first, second
end

local function getManager(definition)
    return _G[definition.managerKey]
end

local function getIds(definition)
    local manager = getManager(definition)
    if not manager then return {} end

    local ok, ids = safeCall(manager.GetAllIds)
    if not ok or type(ids) ~= 'table' then return {} end

    local result = copyList(ids)
    table.sort(result, function(left, right)
        return tostring(left) < tostring(right)
    end)
    return result
end

local function getState(targetType, targetId)
    if targetType == Constants.ComponentType.TRANSFORMER then
        return safeCall(TransformerManager and TransformerManager.GetState, targetId)
    end
    if targetType == Constants.ComponentType.FEEDER then
        return safeCall(FeederManager and FeederManager.GetState, targetId)
    end
    if targetType == Constants.ComponentType.SUBSTATION then
        return safeCall(SubstationManager and SubstationManager.GetState, targetId)
    end
    return false, 'unsupported random failure target type'
end

local function hasBlockingAncestor(targetType, targetId)
    if not FailureManager then return false end

    if targetType ~= Constants.ComponentType.TRANSFORMER
        and type(FailureManager.IsBlocked) == 'function' then
        local ok, blocked = safeCall(FailureManager.IsBlocked, targetType, targetId)
        if ok and blocked then return true end
    end

    if type(FailureManager.GetBlockingAncestor) ~= 'function' then return false end
    local ok, blocker = safeCall(FailureManager.GetBlockingAncestor, targetType, targetId)
    return ok and blocker ~= nil
end

local function isTargetOffline(targetType, state)
    if type(state) ~= 'table' then return true end

    if targetType == Constants.ComponentType.TRANSFORMER then
        return state.state ~= Constants.TransformerState.ONLINE
            and state.state ~= Constants.TransformerState.DEGRADED
    end

    return state.forcedOffline == true
        or state.status == Constants.GridStatus.BLACKOUT
end

local function getActiveIncident(targetType, targetId)
    if not IncidentManager or type(IncidentManager.GetActiveIncidentForTarget) ~= 'function' then
        return nil
    end

    local ok, incident = safeCall(IncidentManager.GetActiveIncidentForTarget, targetType, targetId)
    return ok and incident or nil
end

local function buildActiveDistrictSet()
    local result = {}
    if not IncidentManager or type(IncidentManager.GetAllActiveIncidents) ~= 'function' then
        return result
    end

    local ok, incidents = safeCall(IncidentManager.GetAllActiveIncidents)
    if not ok or type(incidents) ~= 'table' then return result end

    for _, incident in ipairs(incidents) do
        local districts = incident.affectedDistricts or incident.districts or {}
        for _, districtId in ipairs(districts) do
            result[districtId] = true
        end
    end

    return result
end

local function calculateImpact(targetType, targetId)
    if not IncidentImpact or type(IncidentImpact.Calculate) ~= 'function' then
        return nil, 'incident impact dependency unavailable'
    end

    local ok, impact, err = safeCall(IncidentImpact.Calculate, targetType, targetId)
    if not ok then return nil, impact end
    if type(impact) ~= 'table' then return nil, err or 'invalid incident impact' end

    local districts = copyList(impact.affectedDistricts or impact.districts)
    if #districts == 0 then return nil, 'target has no affected districts' end

    impact.affectedDistricts = districts
    return impact
end

local function getRecentFailure(targetType, targetId, state)
    if targetType == Constants.ComponentType.TRANSFORMER and type(state) == 'table' then
        return state.lastFailure
    end
    return lastFailureByTarget[targetKey(targetType, targetId)]
end

local function recentFailureFactor(targetType, targetId, state, now, cooldownSec)
    local lastFailure = getRecentFailure(targetType, targetId, state)
    if type(lastFailure) ~= 'number' or cooldownSec <= 0 then return 1.0 end

    local age = math.max(0, now - lastFailure)
    return clamp(age / (cooldownSec * 4), 0.25, 1.0)
end

local function buildWeight(targetType, targetId, state, impact, typeWeight, now, cooldownSec)
    local damage = 0
    local conditionFactor = 1.0

    if targetType == Constants.ComponentType.TRANSFORMER then
        damage = clamp(tonumber(state.damage) or 0, 0, 100)
        conditionFactor = conditionFactors[state.condition] or 1.0
    end

    local impactFactor = 1 / math.max(1, #impact.affectedDistricts)
    return typeWeight
        * conditionFactor
        * (1 + (damage / 100))
        * recentFailureFactor(targetType, targetId, state, now, cooldownSec)
        * impactFactor
end

local function appendDistricts(set, districts)
    for _, districtId in ipairs(districts or {}) do
        set[districtId] = true
    end
end

local function countKeys(set)
    local count = 0
    for _ in pairs(set) do count = count + 1 end
    return count
end

local function buildCandidate(definition, targetId, activeDistricts, config, now)
    local typeWeight = tonumber(config[definition.weightKey]) or 0
    if typeWeight <= 0 then return nil end

    local ok, state = getState(definition.targetType, targetId)
    if not ok or isTargetOffline(definition.targetType, state) then return nil end
    if hasBlockingAncestor(definition.targetType, targetId) then return nil end
    if getActiveIncident(definition.targetType, targetId) then return nil end

    local impact, impactErr = calculateImpact(definition.targetType, targetId)
    if not impact then return nil, impactErr end

    local combinedDistricts = {}
    for districtId in pairs(activeDistricts) do
        combinedDistricts[districtId] = true
    end
    appendDistricts(combinedDistricts, impact.affectedDistricts)

    if countKeys(combinedDistricts) > config.maxAutomaticOfflineDistricts then
        return nil, 'automatic offline district limit exceeded'
    end

    local weight = buildWeight(
        definition.targetType,
        targetId,
        state,
        impact,
        typeWeight,
        now,
        config.cooldownSec
    )
    if weight <= 0 then return nil end

    return {
        targetType = definition.targetType,
        targetId = targetId,
        state = state,
        impact = impact,
        weight = weight,
    }
end

local function buildCandidates(config, activeDistricts, now)
    local candidates = {}

    for _, definition in ipairs(targetDefinitions) do
        for _, targetId in ipairs(getIds(definition)) do
            local candidate = buildCandidate(definition, targetId, activeDistricts, config, now)
            if candidate then candidates[#candidates + 1] = candidate end
        end
    end

    table.sort(candidates, function(left, right)
        if left.targetType == right.targetType then
            return tostring(left.targetId) < tostring(right.targetId)
        end
        return left.targetType < right.targetType
    end)

    return candidates
end

local function chooseCandidate(candidates)
    local totalWeight = 0
    for _, candidate in ipairs(candidates) do
        totalWeight = totalWeight + candidate.weight
    end
    if totalWeight <= 0 then return nil, 'no positive candidate weight' end

    local ok, roll = safeCall(randomProvider, totalWeight, candidates)
    if not ok then return nil, roll end
    if type(roll) ~= 'number' or roll < 0 or roll >= totalWeight then
        return nil, 'random provider returned invalid roll'
    end

    local cursor = 0
    for _, candidate in ipairs(candidates) do
        cursor = cursor + candidate.weight
        if roll < cursor then return candidate end
    end

    return candidates[#candidates]
end

local function applyCandidate(candidate)
    local reason = 'automatic_random_failure'
    local context = {
        cause = Constants.IncidentCause.RANDOM_FAILURE,
        source = 'RANDOM_FAILURE',
        severity = 100,
    }

    if candidate.targetType == Constants.ComponentType.TRANSFORMER then
        if not TransformerManager or type(TransformerManager.SetDamage) ~= 'function' then
            return false, 'transformer manager unavailable'
        end
        return safeCall(TransformerManager.SetDamage, candidate.targetId, 100, reason, context)
    end

    if not FailureManager or type(FailureManager.SetState) ~= 'function' then
        return false, 'failure manager unavailable'
    end

    return safeCall(
        FailureManager.SetState,
        candidate.targetType,
        candidate.targetId,
        Constants.ComponentState.OFFLINE,
        reason,
        'RANDOM_FAILURE',
        context
    )
end

local function nowValue(explicitNow)
    if explicitNow ~= nil then return explicitNow end
    local ok, value = safeCall(clockProvider)
    if not ok then return nil, value end
    if type(value) ~= 'number' then return nil, 'clock provider returned non-number' end
    return value
end

function RandomFailureManager.Tick(explicitNow)
    local config = Config.RandomFailure
    if type(config) ~= 'table' or config.enabled ~= true then
        return { status = 'SKIPPED', reason = 'disabled' }
    end

    local now, nowErr = nowValue(explicitNow)
    if now == nil then
        return { status = 'SKIPPED', reason = nowErr or 'clock unavailable' }
    end

    local ok, playerCount = safeCall(playerCountProvider)
    if not ok or (tonumber(playerCount) or 0) < 1 then
        return { status = 'SKIPPED', reason = 'no_players' }
    end

    if lastAutomaticFailureAt
        and now - lastAutomaticFailureAt < config.cooldownSec then
        return { status = 'SKIPPED', reason = 'cooldown' }
    end

    local activeDistricts = buildActiveDistrictSet()
    local candidates = buildCandidates(config, activeDistricts, now)
    if #candidates == 0 then
        return { status = 'SKIPPED', reason = 'no_candidates' }
    end

    local candidate, chooseErr = chooseCandidate(candidates)
    if not candidate then
        safeLogWarning('random failure selection rejected', { error = chooseErr })
        return { status = 'REJECTED', reason = chooseErr or 'selection_failed' }
    end

    local mutationOk, mutationResult, mutationErr = applyCandidate(candidate)
    if not mutationOk or mutationResult ~= true then
        local errorMessage = mutationErr or mutationResult or 'failure mutation rejected'
        safeLogWarning('random failure mutation rejected', {
            targetType = candidate.targetType,
            targetId = candidate.targetId,
            error = tostring(errorMessage),
        })
        return {
            status = 'REJECTED',
            reason = tostring(errorMessage),
            targetType = candidate.targetType,
            targetId = candidate.targetId,
        }
    end

    lastAutomaticFailureAt = now
    lastFailureByTarget[targetKey(candidate.targetType, candidate.targetId)] = now

    return {
        status = 'TRIGGERED',
        targetType = candidate.targetType,
        targetId = candidate.targetId,
        affectedDistricts = copyList(candidate.impact.affectedDistricts),
        estimatedImpact = candidate.impact.estimatedImpact,
        weight = candidate.weight,
    }
end

function RandomFailureManager.Start()
    if running then return true end

    local config = Config.RandomFailure
    if type(config) ~= 'table' or config.enabled ~= true then
        return false, 'disabled'
    end
    if type(CreateThread) ~= 'function' or type(Wait) ~= 'function' then
        return false, 'scheduler natives unavailable'
    end

    schedulerGeneration = schedulerGeneration + 1
    local generation = schedulerGeneration
    running = true
    CreateThread(function()
        while running and schedulerGeneration == generation do
            Wait(math.floor(config.tickSec * 1000))
            if running and schedulerGeneration == generation then
                local ok, result = pcall(RandomFailureManager.Tick)
                if not ok then
                    safeLogWarning('random failure tick crashed', { error = tostring(result) })
                end
            end
        end
    end)

    return true
end

function RandomFailureManager.Stop()
    running = false
    schedulerGeneration = schedulerGeneration + 1
end

function RandomFailureManager.SetRandomProvider(provider)
    if provider == nil then
        randomProvider = defaultRandomProvider
        return true
    end
    if type(provider) ~= 'function' then return false, 'random provider must be a function' end
    randomProvider = provider
    return true
end

function RandomFailureManager.SetClock(provider)
    if provider == nil then
        clockProvider = defaultClock
        return true
    end
    if type(provider) ~= 'function' then return false, 'clock provider must be a function' end
    clockProvider = provider
    return true
end

function RandomFailureManager.SetPlayerCountProvider(provider)
    if provider == nil then
        playerCountProvider = defaultPlayerCountProvider
        return true
    end
    if type(provider) ~= 'function' then return false, 'player provider must be a function' end
    playerCountProvider = provider
    return true
end

-- Test-only reset. No export is registered for this function.
function RandomFailureManager.ResetForTests()
    running = false
    schedulerGeneration = schedulerGeneration + 1
    lastAutomaticFailureAt = nil
    lastFailureByTarget = {}
    clockProvider = defaultClock
    randomProvider = defaultRandomProvider
    playerCountProvider = defaultPlayerCountProvider
end
