--[[
    bridge/target/menu_helper.lua

    Shared multi-option interaction menu (client-only), used by every
    target adapter that needs to offer more than one action on the same
    interactable (e.g. Sandy's transformer — Termit vs C4 vs Repair).

    This is the ONLY function that knows about menuv. Both
    bridge/target/standalone.lua and bridge/target/textui.lua call
    MenuHelper.OpenOptions() instead of touching MenuV directly, so a
    future custom NUI replaces menuv here once, not in every adapter that
    happens to support multi-option specs.
]]

if IsDuplicityVersion() then return end

MenuHelper = {}

function MenuHelper.OpenOptions(spec)
    local options = spec.options
    if not options or #options == 0 then return end

    if #options == 1 then
        if options[1].action then options[1].action() end
        return
    end

    if GetResourceState('menuv') ~= 'started' then
        -- Defensive only — fxmanifest.lua's '@menuv/menuv.lua' import
        -- already fails resource start if menuv isn't running (menuv is
        -- a real hard dependency, same as ox_lib), so this branch should
        -- be unreachable in practice. Kept as a fail-open fallback rather
        -- than deleted in case that import is ever removed.
        if options[1].action then options[1].action() end
        return
    end

    local menu = MenuV:CreateMenu(spec.label or 'Etkileşim', 'Bir işlem seçin', 'topleft', 255, 165, 0)

    -- `opt` is a fresh local per loop iteration (Lua's generic for), so
    -- each button's closure safely captures its own option — no
    -- shared-upvalue bug across buttons.
    for _, opt in ipairs(options) do
        menu:AddButton({
            icon = opt.icon or '⚡',
            label = opt.label or 'Seçenek',
            description = opt.description,
            select = function()
                -- menuv does NOT auto-close on button select (confirmed
                -- in menuv.lua — only closes if you navigate into a
                -- submenu via `value = otherMenu`), so it stays open
                -- covering the screen unless we close it ourselves.
                menu:Close()
                if opt.action then opt.action() end
            end,
        })
    end

    MenuV:OpenMenu(menu)
end
