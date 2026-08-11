local defaultConfig = Config.RandomFailure

local function config(overrides)
    local result = {
        enabled = true,
        tickSec = 60,
        transformerWeight = 1.0,
        feederWeight = 0.0,
        substationWeight = 0.0,
        maxAutomaticOfflineDistricts = 6,
        cooldownSec = 300,
    }
    for key, value in pairs(overrides or {}) do
        result[key] = value
    end
    return result
end

local function copy(list)
    local result = {}
    for _, value in ipairs(list or {}) do result[#result + 1] = value end
    return result
end

local function setup(overrides)
    RandomFailureManager.ResetForTests()
    Config.RandomFailure = config(overrides)

    local state = {
        transformer = {
            tr_good = {
                state = Constants.TransformerState.ONLINE,
                damage = 0,
                condition = Constants.Condition.HEALTHY,
            },
        },
        feeder = {
            feed_a = { status = Constants.GridStatus.ONLINE, forcedOffline = false },
        },
        substation = {
            sub_a = { status = Constants.GridStatus.ONLINE, forcedOffline = false },
        },
    }
    local impacts = {
        ['transformer:tr_good'] = { affectedDistricts = { 'SANDY' } },
        ['feeder:feed_a'] = { affectedDistricts = { 'SANDY' } },
        ['substation:sub_a'] = { affectedDistricts = { 'SANDY' } },
    }
    local blocked = {}
    local active = {}
    local activeList = {}
    local mutation = { transformer = nil, parent = nil }
    local playerCount = 1

    local function ids(bucket)
        local result = {}
        for id in pairs(bucket) do result[#result + 1] = id end
        return result
    end

    TransformerManager = {
        GetAllIds = function() return ids(state.transformer) end,
        GetState = function(id) return state.transformer[id] end,
        SetDamage = function(id, damage, reason, context)
            mutation.transformer = { id = id, damage = damage, reason = reason, context = context }
            return true
        end,
    }
    FeederManager = {
        GetAllIds = function() return ids(state.feeder) end,
        GetState = function(id) return state.feeder[id] end,
    }
    SubstationManager = {
        GetAllIds = function() return ids(state.substation) end,
        GetState = function(id) return state.substation[id] end,
    }
    FailureManager = {
        IsBlocked = function(targetType, targetId)
            return blocked[('%s:%s'):format(targetType, targetId)] == true
        end,
        GetBlockingAncestor = function(targetType, targetId)
            return blocked[('%s:%s'):format(targetType, targetId)] and { type = 'test', id = targetId } or nil
        end,
        SetState = function(targetType, targetId, targetState, reason, source, context)
            mutation.parent = {
                targetType = targetType,
                targetId = targetId,
                state = targetState,
                reason = reason,
                source = source,
                context = context,
            }
            return true
        end,
    }
    IncidentManager = {
        GetActiveIncidentForTarget = function(targetType, targetId)
            return active[('%s:%s'):format(targetType, targetId)]
        end,
        GetAllActiveIncidents = function() return activeList end,
    }
    IncidentImpact = {
        Calculate = function(targetType, targetId)
            local impact = impacts[('%s:%s'):format(targetType, targetId)]
            if not impact then return nil, 'unknown test impact' end
            return {
                affectedDistricts = copy(impact.affectedDistricts),
                estimatedImpact = { districtCount = #impact.affectedDistricts, playerCount = 1 },
            }
        end,
    }

    RandomFailureManager.SetPlayerCountProvider(function() return playerCount end)
    RandomFailureManager.SetRandomProvider(function()
        return 0
    end)

    return {
        state = state,
        impacts = impacts,
        blocked = blocked,
        active = active,
        activeList = activeList,
        mutation = mutation,
        setPlayerCount = function(value) playerCount = value end,
    }
end

TEST('random failure disabled does not mutate state', function()
    local env = setup({ enabled = false })
    local result = RandomFailureManager.Tick(100)
    ASSERT_EQ(result.status, 'SKIPPED', 'disabled scheduler must skip')
    ASSERT_EQ(env.mutation.transformer, nil, 'disabled scheduler must not mutate transformer')
end)

TEST('random failure skips when no player is online', function()
    local env = setup({})
    env.setPlayerCount(0)
    local result = RandomFailureManager.Tick(100)
    ASSERT_EQ(result.reason, 'no_players', 'empty server must skip')
    ASSERT_EQ(env.mutation.transformer, nil, 'empty server must not mutate transformer')
end)

TEST('default weights select transformer and pass random failure context', function()
    local env = setup({})
    local result = RandomFailureManager.Tick(100)
    ASSERT_EQ(result.status, 'TRIGGERED', 'transformer candidate must trigger')
    ASSERT_EQ(result.targetType, Constants.ComponentType.TRANSFORMER, 'default target type must be transformer')
    ASSERT_EQ(env.mutation.transformer.id, 'tr_good', 'deterministic provider must select transformer')
    ASSERT_EQ(env.mutation.transformer.damage, 100, 'automatic failure must destroy transformer')
    ASSERT_EQ(env.mutation.transformer.context.cause, Constants.IncidentCause.RANDOM_FAILURE, 'cause must be random failure')
    ASSERT_EQ(env.mutation.transformer.context.source, 'RANDOM_FAILURE', 'source must be random failure')
end)

TEST('offline, blocked, and active targets are excluded', function()
    local env = setup({})
    env.state.transformer.tr_offline = {
        state = Constants.TransformerState.OFFLINE,
        damage = 100,
        condition = Constants.Condition.DESTROYED,
    }
    env.state.transformer.tr_blocked = {
        state = Constants.TransformerState.ONLINE,
        damage = 0,
        condition = Constants.Condition.HEALTHY,
    }
    env.state.transformer.tr_active = {
        state = Constants.TransformerState.ONLINE,
        damage = 0,
        condition = Constants.Condition.HEALTHY,
    }
    env.impacts['transformer:tr_offline'] = { affectedDistricts = { 'DOWNT' } }
    env.impacts['transformer:tr_blocked'] = { affectedDistricts = { 'VESPU' } }
    env.impacts['transformer:tr_active'] = { affectedDistricts = { 'GROVE' } }
    env.blocked['transformer:tr_blocked'] = true
    env.active['transformer:tr_active'] = { incidentId = 'incident-1' }

    local result = RandomFailureManager.Tick(100)
    ASSERT_EQ(result.targetId, 'tr_good', 'only eligible transformer must remain')
end)

TEST('district limit counts overlapping districts once', function()
    local env = setup({ maxAutomaticOfflineDistricts = 2 })
    env.activeList[1] = { affectedDistricts = { 'SANDY', 'DOWNT' } }
    env.impacts['transformer:tr_good'] = { affectedDistricts = { 'DOWNT', 'VESPU' } }
    local rejected = RandomFailureManager.Tick(100)
    ASSERT_EQ(rejected.reason, 'no_candidates', 'district limit must reject three unique districts')

    env = setup({ maxAutomaticOfflineDistricts = 3 })
    env.activeList[1] = { affectedDistricts = { 'SANDY', 'DOWNT' } }
    env.impacts['transformer:tr_good'] = { affectedDistricts = { 'DOWNT', 'VESPU' } }
    local accepted = RandomFailureManager.Tick(100)
    ASSERT_EQ(accepted.status, 'TRIGGERED', 'exact district limit must be accepted')
end)

TEST('cooldown blocks second automatic failure', function()
    local env = setup({ cooldownSec = 300 })
    local first = RandomFailureManager.Tick(100)
    ASSERT_EQ(first.status, 'TRIGGERED', 'first failure must trigger')
    env.mutation.transformer = nil
    local second = RandomFailureManager.Tick(200)
    ASSERT_EQ(second.reason, 'cooldown', 'second failure must respect cooldown')
    ASSERT_EQ(env.mutation.transformer, nil, 'cooldown must prevent mutation')
end)

TEST('failed mutation does not start cooldown', function()
    local env = setup({ cooldownSec = 300 })
    TransformerManager.SetDamage = function()
        return false, 'mutation failed'
    end

    local rejected = RandomFailureManager.Tick(100)
    ASSERT_EQ(rejected.status, 'REJECTED', 'failed mutation must be rejected')

    TransformerManager.SetDamage = function(id, damage, reason, context)
        env.mutation.transformer = { id = id, damage = damage, reason = reason, context = context }
        return true
    end
    local retried = RandomFailureManager.Tick(101)
    ASSERT_EQ(retried.status, 'TRIGGERED', 'failed mutation must not consume cooldown')
end)

TEST('parent weights use FailureManager with random context', function()
    local env = setup({ transformerWeight = 0, feederWeight = 1 })
    local result = RandomFailureManager.Tick(100)
    ASSERT_EQ(result.targetType, Constants.ComponentType.FEEDER, 'feeder weight must select feeder')
    ASSERT_EQ(env.mutation.parent.targetId, 'feed_a', 'selected feeder must be mutated')
    ASSERT_EQ(env.mutation.parent.state, Constants.ComponentState.OFFLINE, 'parent target must go offline')
    ASSERT_EQ(env.mutation.parent.context.cause, Constants.IncidentCause.RANDOM_FAILURE, 'parent cause must be random failure')
end)

TEST('invalid random failure config fails validation', function()
    Config.RandomFailure = {
        enabled = true,
        tickSec = 0,
        transformerWeight = 0,
        feederWeight = 0,
        substationWeight = 0,
        maxAutomaticOfflineDistricts = 0.5,
        cooldownSec = -1,
    }
    local ok, errors = Validators.ValidateAll()
    ASSERT_FALSE(ok, 'invalid random failure config must fail validation')

    local foundWeightError = false
    for _, message in ipairs(errors) do
        if message:find('positive target weight', 1, true) then
            foundWeightError = true
        end
    end
    ASSERT_TRUE(foundWeightError, 'validation must report zero enabled weight')
    Config.RandomFailure = defaultConfig
end)

RandomFailureManager.ResetForTests()
Config.RandomFailure = defaultConfig
