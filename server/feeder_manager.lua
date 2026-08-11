--[[
    server/feeder_manager.lua

    Feeder is a distinct entity (spec §12, §18.3) but — same as
    server/substation_manager.lua — its state is always DERIVED from its
    transformers, never stored independently. Reuses the exact same pure
    PowerCalculator.Calculate() function grid-level power already uses:
    a feeder's `powerPolicy` (shared/feeders.lua) is evaluated against its
    own transformer list exactly like a grid's powerPolicy is evaluated
    against its own — there's no reason for a second policy evaluator.
]]

FeederManager = {}

function FeederManager.GetState(feederId)
    local feeder = Feeders[feederId]
    if not feeder then return nil end

    local blockedBy = FailureManager and FailureManager.GetBlockingAncestor(Constants.ComponentType.FEEDER, feederId)
    if blockedBy then
        return {
            feederId = feederId,
            substationId = feeder.substationId,
            label = feeder.label,
            districts = feeder.districts,
            powered = false,
            level = 0.0,
            status = Constants.GridStatus.BLACKOUT,
            forcedOffline = true,
            blockedBy = blockedBy,
        }
    end

    local trList = {}
    for _, trId in ipairs(feeder.transformers) do
        local def = Transformers[trId]
        local rt = TransformerManager.GetState(trId)
        if def and rt then
            trList[#trList + 1] = { id = trId, primary = def.primary == true, state = rt.state }
        end
    end

    local result = PowerCalculator.Calculate(feeder, trList)

    return {
        feederId = feederId,
        substationId = feeder.substationId,
        label = feeder.label,
        districts = feeder.districts,
        powered = result.powered,
        level = result.level,
        status = result.status,
        forcedOffline = false,
        blockedBy = result.blockedBy,
    }
end

function FeederManager.GetAllIds()
    local ids = {}
    for feederId in pairs(Feeders or {}) do
        ids[#ids + 1] = feederId
    end
    return ids
end
