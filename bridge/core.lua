--[[
    bridge/core.lua

    Framework-free bridge contracts.  Adapter files only register functions;
    loader.lua selects a complete snapshot and publishes it atomically.
    This file has no FiveM calls so aliases/contracts can be unit-tested with
    stock Lua.
]]

BridgeCore = {}

local aliases = {
    framework = {
        auto = 'auto', standalone = 'standalone', none = 'standalone',
        qb = 'qbcore', qbcore = 'qbcore', ['qb-core'] = 'qbcore',
        qbox = 'qbox', qbx = 'qbox', ['qbx-core'] = 'qbox', ['qbx_core'] = 'qbox',
        esx = 'esx', ['esx-legacy'] = 'esx', ['es_extended'] = 'esx',
    },
    inventory = {
        auto = 'auto', none = 'none', framework = 'framework',
        ox = 'ox_inventory', ['ox-inventory'] = 'ox_inventory', ox_inventory = 'ox_inventory',
        qs = 'qs_inventory', ['qs-inventory'] = 'qs_inventory', qs_inventory = 'qs_inventory',
        ps = 'ps_inventory', ['ps-inventory'] = 'ps_inventory', ps_inventory = 'ps_inventory',
        qb = 'qb_inventory', ['qb-inventory'] = 'qb_inventory', qb_inventory = 'qb_inventory',
    },
    target = {
        auto = 'auto', none = 'none', standalone = 'standalone',
        ox = 'ox_target', ['ox-target'] = 'ox_target', ox_target = 'ox_target',
        qb = 'qb_target', ['qb-target'] = 'qb_target', qb_target = 'qb_target',
        qtarget = 'qtarget', ['q-target'] = 'qtarget',
        textui = 'textui',
    },
    notify = {
        auto = 'auto', framework = 'framework', internal = 'internal',
        ox = 'ox_lib', ['ox-lib'] = 'ox_lib', ox_lib = 'ox_lib',
        nui = 'nui', universal = 'nui', ['universal-ui'] = 'nui', ['universal_ui'] = 'nui',
    },
    menu = {
        auto = 'auto', internal = 'internal', framework = 'framework',
        ox = 'ox_lib', ['ox-lib'] = 'ox_lib', ox_lib = 'ox_lib',
        qb = 'qb_menu', ['qb-menu'] = 'qb_menu', qb_menu = 'qb_menu',
        menuv = 'menuv',
        nui = 'nui', universal = 'nui', ['universal-ui'] = 'nui', ['universal_ui'] = 'nui',
    },
    progress = {
        auto = 'auto', internal = 'internal',
        ox = 'ox_lib', ['ox-lib'] = 'ox_lib', ox_lib = 'ox_lib',
        progressbar = 'progressbar', ['progress-bar'] = 'progressbar',
        nui = 'nui', universal = 'nui', ['universal-ui'] = 'nui', ['universal_ui'] = 'nui',
    },
    skillcheck = {
        auto = 'auto', internal = 'internal',
        ox = 'ox_lib', ['ox-lib'] = 'ox_lib', ox_lib = 'ox_lib',
        qb = 'qb_lock', ['qb-lock'] = 'qb_lock', qb_lock = 'qb_lock',
        nui = 'nui', universal = 'nui', ['universal-ui'] = 'nui', ['universal_ui'] = 'nui',
    },
    database = {
        auto = 'auto', memory = 'memory', ox = 'oxmysql', oxmysql = 'oxmysql',
    },
}

local required = {
    framework = {
        server = { 'GetPlayer', 'GetJob', 'HasPermission', 'Notify' },
        client = { 'GetPlayerData', 'Notify' },
    },
    inventory = { server = { 'HasItem', 'AddItem', 'RemoveItem' } },
    target = { client = { 'RegisterInteractable', 'RemoveInteractable' } },
    notify = { client = { 'Notify' }, server = { 'Notify' } },
    menu = { client = { 'OpenMenu' } },
    progress = { client = { 'Progress', 'CancelProgress' } },
    skillcheck = { client = { 'SkillCheck' } },
    database = { server = { 'Available', 'Query', 'Insert', 'Update' } },
}

function BridgeCore.Normalize(category, value)
    if type(value) ~= 'string' then return nil end
    local map = aliases[category]
    if not map then return nil end
    return map[string.lower(value)]
end

function BridgeCore.GetAliases(category)
    local result = {}
    for key, value in pairs(aliases[category] or {}) do result[key] = value end
    return result
end

function BridgeCore.ValidateAdapter(category, adapter, side)
    local missing = {}
    local contract = required[category] and required[category][side] or {}
    if type(adapter) ~= 'table' then
        for _, name in ipairs(contract) do missing[#missing + 1] = name end
        return false, missing
    end

    for _, name in ipairs(contract) do
        if type(adapter[name]) ~= 'function' then missing[#missing + 1] = name end
    end
    return #missing == 0, missing
end

function BridgeCore.Copy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, item in pairs(value) do copy[BridgeCore.Copy(key, seen)] = BridgeCore.Copy(item, seen) end
    return copy
end

function BridgeCore.Select(preference, candidates, fallback)
    local desired = preference or 'auto'
    if desired ~= 'auto' then
        for _, candidate in ipairs(candidates or {}) do
            if candidate.key == desired and candidate.available then
                return candidate.key, nil
            end
        end
        return fallback, ('explicit adapter unavailable: %s'):format(tostring(desired))
    end

    for _, candidate in ipairs(candidates or {}) do
        if candidate.available then return candidate.key, nil end
    end
    return fallback, 'no compatible adapter detected'
end

function BridgeCore.RequiredContracts()
    local result = {}
    for category, sides in pairs(required) do
        result[category] = {}
        for side, names in pairs(sides) do
            result[category][side] = {}
            for index, name in ipairs(names) do result[category][side][index] = name end
        end
    end
    return result
end
