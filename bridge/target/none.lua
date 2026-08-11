--[[
    bridge/target/none.lua

    No-target fallback (client-only). RegisterInteractable is a no-op that
    prints a warning so a missing/misconfigured target adapter fails
    loudly during development instead of silently doing nothing.
]]

if IsDuplicityVersion() then return end

TargetAdapters = TargetAdapters or {}
TargetAdapters.none = {}

local A = TargetAdapters.none

function A.RegisterInteractable(spec)
    print(('^3[gnsh-blackout] no target adapter active — interactable "%s" was not registered^7'):format(tostring(spec.id)))
end

function A.RemoveInteractable(_id)
end
