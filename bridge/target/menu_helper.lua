-- Compatibility helper kept for adapters/extensions that still call it.
-- Menu implementation lives in bridge/menu/* and is selected by Bridge.

if IsDuplicityVersion() then return end
MenuHelper = {}

function MenuHelper.OpenOptions(spec)
    if Bridge and Bridge.OpenMenu then return Bridge.OpenMenu(spec) end
    local first = spec and spec.options and spec.options[1]
    if first and first.action then first.action() end
end

