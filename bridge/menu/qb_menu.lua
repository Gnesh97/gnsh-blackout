-- qb-menu adapter with a tokenized client callback registry.

if IsDuplicityVersion() then return end
MenuAdapters = MenuAdapters or {}
MenuAdapters.qb_menu = {}
local A = MenuAdapters.qb_menu
local actions = {}
local counter = 0

RegisterNetEvent('gnsh-blackout:client:qbMenuAction', function(data, legacyIndex)
    -- qb-menu sends params.args as one table. Keep the two-argument form as
    -- a compatibility fallback for older menu wrappers.
    local token, index
    if type(data) == 'table' then
        token = data.token or data[1]
        index = data.index or data[2]
    else
        token = data
        index = legacyIndex
    end

    local entry = actions[token]
    local option = entry and entry[tonumber(index)]
    if not option then return end
    actions[token] = nil
    if option.action then option.action() end
end)

function A.OpenMenu(spec)
    if GetResourceState('qb-menu') ~= 'started' then return MenuAdapters.internal.OpenMenu(spec) end
    counter = counter + 1
    local token = ('qbmenu-%d'):format(counter)
    actions[token] = spec.options or {}
    local entries = {}
    for index, option in ipairs(spec.options or {}) do
        entries[#entries + 1] = {
            header = option.label or 'Seçenek',
            txt = option.description or '',
            icon = option.icon,
            params = {
                event = 'gnsh-blackout:client:qbMenuAction',
                args = { token = token, index = index },
            },
        }
    end
    local ok = pcall(function() exports['qb-menu']:openMenu(entries) end)
    if not ok then actions[token] = nil; return MenuAdapters.internal.OpenMenu(spec) end
    return true
end
