--[[
    client/visual/hybrid.lua

    Optional Phase 28 adapter hook. Custom assets can be attached here later;
    failures are isolated and never mutate server logical state.
]]

VisualHybrid = {}

function VisualHybrid.Apply(profile, enabled)
    if type(profile) ~= 'table' then return false end
    if profile.mode ~= Constants.VisualMode.HYBRID then return true end
    -- No custom asset is shipped yet. Native blackout remains the fallback.
    return enabled == true or enabled == false
end

function VisualHybrid.Reset()
    -- Reserved for future hybrid assets.
end
