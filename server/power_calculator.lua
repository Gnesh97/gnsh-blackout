--[[
    server/power_calculator.lua

    Pure power policy evaluator (spec §15, §16). No side effects, no
    global state — takes a grid definition and an array of merged
    transformer info, returns { powered, level, status }. This purity is
    deliberate: it makes the four policies exhaustively unit-testable
    (tests/spec/power_policy_spec.lua) without any FiveM natives, and
    keeps server/replication.lua (the caller) as the only place that
    decides WHEN to recalculate.

    `transformers` shape (built by the caller from Transformers[id] +
    TransformerManager.GetState(id)):
        { { id = 'sandy_tr_01', primary = true, state = 'ONLINE' }, ... }

    Only PRIMARY / ANY / ALL / REQUIRED_COUNT are implemented — the
    validator (shared/validators.lua) rejects any grid configured with
    WEIGHTED_CAPACITY / PRIMARY_BACKUP / CUSTOM before this module is ever
    asked to evaluate one (spec §73: "sonraki iteration").

    THREE-TIER EVALUATION (spec §16 level semantics):
      1. Try the policy counting only ONLINE transformers as "up".
         If satisfied -> full power (level 1.0, status ONLINE).
      2. Otherwise, try the SAME policy counting ONLINE+DEGRADED as "up".
         If satisfied -> degraded power (level = Config.DegradedLevel,
         status DEGRADED) — unless DegradedLevel itself falls below
         Config.BlackoutThreshold, in which case it's still a blackout.
      3. Otherwise -> blackout (level 0.0).
]]

PowerCalculator = {}

local function countMatching(transformers, statesSet)
    local count = 0
    local primaryMatches = false
    for _, tr in ipairs(transformers) do
        if statesSet[tr.state] then
            count = count + 1
            if tr.primary then primaryMatches = true end
        end
    end
    return count, primaryMatches
end

local function evaluatePolicy(grid, transformers, statesSet)
    local policy = grid.powerPolicy
    local mode = policy.mode
    local total = #transformers
    local matchCount, primaryMatches = countMatching(transformers, statesSet)

    if mode == Constants.PowerPolicy.PRIMARY then
        return primaryMatches
    elseif mode == Constants.PowerPolicy.ANY then
        return matchCount > 0
    elseif mode == Constants.PowerPolicy.ALL then
        return total > 0 and matchCount == total
    elseif mode == Constants.PowerPolicy.REQUIRED_COUNT then
        return matchCount >= (policy.requiredOnline or math.huge)
    end

    -- Unknown/unimplemented mode — validator should have caught this at
    -- startup, but fail closed (unpowered) rather than silently granting
    -- power for a policy we don't understand.
    return false
end

local ONLINE_ONLY = { [Constants.TransformerState.ONLINE] = true }
local ONLINE_OR_DEGRADED = {
    [Constants.TransformerState.ONLINE] = true,
    [Constants.TransformerState.DEGRADED] = true,
}

function PowerCalculator.Calculate(grid, transformers)
    if evaluatePolicy(grid, transformers, ONLINE_ONLY) then
        return { powered = true, level = 1.0, status = Constants.GridStatus.ONLINE }
    end

    if evaluatePolicy(grid, transformers, ONLINE_OR_DEGRADED) then
        local level = Config.DegradedLevel
        if level < Config.BlackoutThreshold then
            return { powered = false, level = 0.0, status = Constants.GridStatus.BLACKOUT }
        end
        return { powered = true, level = level, status = Constants.GridStatus.DEGRADED }
    end

    return { powered = false, level = 0.0, status = Constants.GridStatus.BLACKOUT }
end

-- District-level aggregation across the feeder(s) that supply it (spec
-- §18, Phase 18). `supply` is an array of feeder states, each already
-- computed by FeederManager.GetState (i.e. { powered, level, status }) —
-- this function does not know or care about feeders/transformers, only
-- the pre-computed numbers, same purity discipline as Calculate() above.
--
-- Only Config.Topology.districtPolicy = 'ANY' is implemented (a district
-- is powered if AT LEAST ONE supplying feeder is powered — spec §29.1's
-- partial-recovery example, "Feeder A ONLINE, Feeder B OFFLINE", only
-- makes sense under an ANY-style policy). Any other configured value is
-- rejected by shared/validators.lua before this function is ever called,
-- same "not implemented yet" pattern as Calculate()'s WEIGHTED_CAPACITY.
function PowerCalculator.CalculateDistrict(supply)
    local anyOnline, anyDegraded, bestLevel = false, false, 0.0
    local bestPoweredId = nil
    local firstBlockedBy = nil

    for _, feederState in ipairs(supply) do
        if feederState.blockedBy and not firstBlockedBy then
            firstBlockedBy = feederState.blockedBy
        end
        if feederState.powered then
            if feederState.level >= 1.0 then
                anyOnline = true
            else
                anyDegraded = true
            end
            if feederState.level > bestLevel then
                bestLevel = feederState.level
                bestPoweredId = feederState.feederId
            elseif feederState.level == bestLevel and feederState.feederId and bestPoweredId
                and feederState.feederId < bestPoweredId then
                bestPoweredId = feederState.feederId
            end
        end
    end

    if anyOnline then
        return { powered = true, level = 1.0, status = Constants.GridStatus.ONLINE, sourceFeederId = bestPoweredId }
    end
    if anyDegraded then
        return { powered = true, level = bestLevel, status = Constants.GridStatus.DEGRADED, sourceFeederId = bestPoweredId }
    end
    return { powered = false, level = 0.0, status = Constants.GridStatus.BLACKOUT, blockedBy = firstBlockedBy }
end
