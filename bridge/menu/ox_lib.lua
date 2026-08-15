-- ox_lib context menu adapter.

if IsDuplicityVersion() then return end
MenuAdapters = MenuAdapters or {}
MenuAdapters.ox_lib = {}
local A = MenuAdapters.ox_lib

function A.OpenMenu(spec)
    if not OxLibBridge or type(OxLibBridge.Call) ~= 'function' then
        return MenuAdapters.internal.OpenMenu(spec)
    end

    local id = ('gnsh-blackout:%s'):format(tostring(spec.id or 'interaction'))
    local options = {}
    for _, option in ipairs(spec.options or {}) do
        options[#options + 1] = {
            title = option.label or 'Seçenek',
            description = option.description,
            icon = option.icon,
            onSelect = option.action,
        }
    end

    local registered = OxLibBridge.Call('registerContext', {
        id = id,
        title = spec.label or 'Etkileşim',
        options = options,
    })
    if not registered then return MenuAdapters.internal.OpenMenu(spec) end

    local shown = OxLibBridge.Call('showContext', id)
    if not shown then return MenuAdapters.internal.OpenMenu(spec) end
    return true
end
