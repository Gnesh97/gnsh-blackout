-- Optional MenuV adapter. MenuV is usable only if its global was injected
-- into this resource; otherwise loader selects the native internal fallback.

if IsDuplicityVersion() then return end
MenuAdapters = MenuAdapters or {}
MenuAdapters.menuv = {}
local A = MenuAdapters.menuv

function A.OpenMenu(spec)
    if not MenuV or type(MenuV.CreateMenu) ~= 'function' then
        return MenuAdapters.internal.OpenMenu(spec)
    end
    local menu = MenuV:CreateMenu(spec.label or 'Etkileşim', 'Bir işlem seçin', 'topleft', 255, 165, 0)
    for _, option in ipairs(spec.options or {}) do
        menu:AddButton({
            icon = option.icon or '⚡',
            label = option.label or 'Seçenek',
            description = option.description,
            select = function() menu:Close(); if option.action then option.action() end end,
        })
    end
    MenuV:OpenMenu(menu)
    return true
end
