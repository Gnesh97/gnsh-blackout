--[[
    server/substation_manager.lua

    Substation is a distinct entity from Transformer (spec §12) — its
    state is always DERIVED from its transformers, never stored
    independently. This module is intentionally thin: it has no runtime
    cache of its own, just aggregation helpers over
    TransformerManager.GetState().
]]

SubstationManager = {}

-- Aggregate view of a substation: online/total transformer counts and a
-- coarse status label. Used by /showtransformers and the
-- GetSubstationState() export (spec §48).
function SubstationManager.GetState(substationId)
    local sub = Substations[substationId]
    if not sub then return nil end

    local blockedBy = FailureManager and FailureManager.GetBlockingAncestor(Constants.ComponentType.SUBSTATION, substationId)
    if blockedBy then
        return {
            substationId = substationId,
            gridId = sub.gridId,
            label = sub.label,
            totalTransformers = #sub.transformers,
            onlineTransformers = 0,
            degradedTransformers = 0,
            powered = false,
            level = 0.0,
            status = Constants.GridStatus.BLACKOUT,
            forcedOffline = true,
            blockedBy = blockedBy,
        }
    end

    local total, online, degraded = 0, 0, 0
    for _, trId in ipairs(sub.transformers) do
        local trState = TransformerManager.GetState(trId)
        if trState then
            total = total + 1
            if trState.state == Constants.TransformerState.ONLINE then
                online = online + 1
            elseif trState.state == Constants.TransformerState.DEGRADED then
                degraded = degraded + 1
            end
        end
    end

    local status
    if total == 0 then
        status = Constants.GridStatus.BLACKOUT
    elseif online == total then
        status = Constants.GridStatus.ONLINE
    elseif online == 0 and degraded == 0 then
        status = Constants.GridStatus.BLACKOUT
    elseif online == 0 then
        status = Constants.GridStatus.DEGRADED
    else
        status = Constants.GridStatus.PARTIAL
    end

    return {
        substationId = substationId,
        gridId = sub.gridId,
        label = sub.label,
        totalTransformers = total,
        onlineTransformers = online,
        degradedTransformers = degraded,
        powered = status ~= Constants.GridStatus.BLACKOUT,
        level = total > 0 and (online / total) or 0.0,
        status = status,
        forcedOffline = false,
        blockedBy = nil,
    }
end

function SubstationManager.GetAllIds()
    local ids = {}
    for subId in pairs(Substations) do
        ids[#ids + 1] = subId
    end
    return ids
end
