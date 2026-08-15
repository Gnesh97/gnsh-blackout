-- Explicit no-target adapter.

if IsDuplicityVersion() then return end
TargetAdapters = TargetAdapters or {}
TargetAdapters.none = {}
local A = TargetAdapters.none

function A.RegisterInteractable(spec)
    print(('^3[gnsh-blackout] no target adapter active - interactable "%s" was not registered^7'):format(tostring(spec.id)))
    return false
end

function A.RemoveInteractable(_id)
    return true
end

