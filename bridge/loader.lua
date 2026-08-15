--[[
    bridge/loader.lua

    Runtime adapter selector. Every rebuild publishes a new Bridge table;
    callers see one complete snapshot and never a half-switched category.
    Client interactables are retained by id and rebound exactly once when the
    active target resource starts/stops.
]]

local function warn(message)
    print(('^3[gnsh-blackout] %s^7'):format(tostring(message)))
end

local function running(name)
    return type(GetResourceState) == 'function' and GetResourceState(name) == 'started'
end

local function currentResource()
    return type(GetCurrentResourceName) == 'function' and GetCurrentResourceName() or 'gnsh-blackout'
end

local function registry(category)
    local names = {
        framework = 'FrameworkAdapters',
        inventory = 'InventoryAdapters',
        target = 'TargetAdapters',
        notify = 'NotifyAdapters',
        menu = 'MenuAdapters',
        progress = 'ProgressAdapters',
        skillcheck = 'SkillcheckAdapters',
        database = 'DatabaseAdapters',
    }
    return _G[names[category] or category] or {}
end

local function usable(category, key, side)
    local adapter = registry(category)[key]
    local ok = BridgeCore.ValidateAdapter(category, adapter, side)
    return ok, adapter
end

local function candidate(key, available)
    return { key = key, available = available == true }
end

local function oxLibAvailable(name)
    return OxLibBridge
        and type(OxLibBridge.IsAvailable) == 'function'
        and OxLibBridge.IsAvailable(name) == true
end

local function preference(category)
    local bridge = Config.Bridge or {}
    local value = bridge[category]
    return value == nil and 'auto' or value
end

local function choose(category, side, candidates, fallback)
    local configured = preference(category)
    local normalized = BridgeCore.Normalize(category, configured)
    local reasons = {}
    if not normalized then
        reasons[#reasons + 1] = ('unknown %s adapter value: %s'):format(category, tostring(configured))
        normalized = 'auto'
    end

    local available = {}
    for _, item in ipairs(candidates) do
        local valid = false
        if item.available then valid = usable(category, item.key, side) end
        available[#available + 1] = candidate(item.key, valid)
    end

    local key, reason = BridgeCore.Select(normalized, available, fallback)
    if reason then reasons[#reasons + 1] = reason end
    local ok, adapter = usable(category, key, side)
    if not ok then
        reasons[#reasons + 1] = ('selected adapter missing required functions: %s'):format(key)
        key = fallback
        adapter = registry(category)[fallback]
    end
    return key, adapter, reasons
end

local function appendReasons(target, category, reasons)
    target[category] = target[category] or {}
    for _, reason in ipairs(reasons or {}) do target[category][#target[category] + 1] = reason end
end

local interactables = {}
local activeTarget
local rebuilding = false
local initialized = false
local watchedResources = {
    ['qbx_core'] = true, ['qb-core'] = true, ['es_extended'] = true,
    ['ox_inventory'] = true, ['qs-inventory'] = true, ['ps-inventory'] = true,
    ['qb-inventory'] = true, ['ox_target'] = true, ['qb-target'] = true,
    ['qtarget'] = true, ['ox_lib'] = true, ['qb-menu'] = true,
    ['menuv'] = true, ['progressbar'] = true, ['qb-lock'] = true,
    ['oxmysql'] = true,
}

local function bridgeInfo()
    return {
        framework = nil,
        inventory = nil,
        target = nil,
        notify = nil,
        menu = nil,
        progress = nil,
        skillcheck = nil,
        database = nil,
        fallbacks = {},
        capabilities = {},
    }
end

local function buildServer()
    local info = bridgeInfo()
    local bridge = {}

    local frameworkKey, framework, frameworkReasons = choose('framework', 'server', {
        candidate('qbox', running('qbx_core')),
        candidate('qbcore', running('qb-core')),
        candidate('esx', running('es_extended')),
        candidate('standalone', true),
    }, 'standalone')
    ActiveFrameworkAdapter = framework
    info.framework = frameworkKey
    appendReasons(info.fallbacks, 'framework', frameworkReasons)

    local inventoryKey, inventory, inventoryReasons = choose('inventory', 'server', {
        candidate('ox_inventory', running('ox_inventory')),
        candidate('qs_inventory', running('qs-inventory')),
        candidate('ps_inventory', running('ps-inventory')),
        candidate('qb_inventory', running('qb-inventory')),
        candidate('framework', frameworkKey ~= 'standalone'),
        candidate('none', true),
    }, 'none')
    info.inventory = inventoryKey
    appendReasons(info.fallbacks, 'inventory', inventoryReasons)

    local notifyKey, notify, notifyReasons = choose('notify', 'server', {
        candidate('nui', type(NotifyAdapters and NotifyAdapters.nui) == 'table'),
        candidate('framework', framework and type(framework.Notify) == 'function'),
        candidate('ox_lib', running('ox_lib')),
        candidate('internal', true),
    }, 'internal')
    info.notify = notifyKey
    appendReasons(info.fallbacks, 'notify', notifyReasons)

    local databaseKey, database, databaseReasons = choose('database', 'server', {
        candidate('oxmysql', running('oxmysql')),
        candidate('memory', true),
    }, 'memory')
    info.database = databaseKey
    appendReasons(info.fallbacks, 'database', databaseReasons)

    local function merge(adapter, names)
        for _, name in ipairs(names) do
            if type(adapter and adapter[name]) == 'function' then bridge[name] = adapter[name] end
        end
    end
    merge(framework, { 'GetPlayer', 'GetJob', 'HasPermission' })
    merge(notify, { 'Notify' })
    merge(inventory, { 'HasItem', 'AddItem', 'RemoveItem' })

    bridge.Database = database
    bridge.Framework = framework
    bridge.Inventory = inventory
    bridge.GetAdapterSnapshot = function() return BridgeCore.Copy(info) end
    bridge.GetDiagnostics = bridge.GetAdapterSnapshot
    info.capabilities = {
        framework = { player = type(bridge.GetPlayer) == 'function', job = type(bridge.GetJob) == 'function', permission = type(bridge.HasPermission) == 'function' },
        inventory = { hasItem = type(bridge.HasItem) == 'function', addItem = type(bridge.AddItem) == 'function', removeItem = type(bridge.RemoveItem) == 'function' },
        database = { available = type(database.Available) == 'function' and database.Available() == true },
    }
    return bridge, info
end

local function buildClient()
    local info = bridgeInfo()
    local bridge = {}
    info.inventory = 'server-only'
    info.database = 'server-only'

    local frameworkKey, framework, frameworkReasons = choose('framework', 'client', {
        candidate('qbox', running('qbx_core')),
        candidate('qbcore', running('qb-core')),
        candidate('esx', running('es_extended')),
        candidate('standalone', true),
    }, 'standalone')
    ActiveFrameworkAdapter = framework
    info.framework = frameworkKey
    appendReasons(info.fallbacks, 'framework', frameworkReasons)

    local targetKey, target, targetReasons = choose('target', 'client', {
        candidate('ox_target', running('ox_target')),
        candidate('qb_target', running('qb-target') and GetConvar('UseTarget', 'false') == 'true'),
        candidate('qtarget', running('qtarget')),
        candidate('textui', running('ox_lib') and _G.lib and _G.lib.points ~= nil),
        candidate('standalone', true),
        candidate('none', true),
    }, 'standalone')
    info.target = targetKey
    appendReasons(info.fallbacks, 'target', targetReasons)

    local notifyKey, notify, notifyReasons = choose('notify', 'client', {
        candidate('nui', type(NotifyAdapters and NotifyAdapters.nui) == 'table'),
        candidate('framework', framework and type(framework.Notify) == 'function'),
        candidate('ox_lib', oxLibAvailable('notify')),
        candidate('internal', true),
    }, 'internal')
    info.notify = notifyKey
    appendReasons(info.fallbacks, 'notify', notifyReasons)

    local menuKey, menu, menuReasons = choose('menu', 'client', {
        candidate('nui', type(MenuAdapters and MenuAdapters.nui) == 'table'),
        candidate('ox_lib', oxLibAvailable('registerContext') and oxLibAvailable('showContext')),
        candidate('qb_menu', running('qb-menu')),
        candidate('menuv', running('menuv') and _G.MenuV ~= nil),
        candidate('internal', true),
    }, 'internal')
    info.menu = menuKey
    appendReasons(info.fallbacks, 'menu', menuReasons)

    local progressKey, progress, progressReasons = choose('progress', 'client', {
        candidate('nui', type(ProgressAdapters and ProgressAdapters.nui) == 'table'),
        candidate('ox_lib', oxLibAvailable('progressBar')),
        candidate('progressbar', running('progressbar')),
        candidate('internal', true),
    }, 'internal')
    info.progress = progressKey
    appendReasons(info.fallbacks, 'progress', progressReasons)

    local skillcheckKey, skillcheck, skillcheckReasons = choose('skillcheck', 'client', {
        candidate('nui', type(SkillcheckAdapters and SkillcheckAdapters.nui) == 'table'),
        candidate('ox_lib', oxLibAvailable('skillCheck')),
        candidate('qb_lock', running('qb-lock')),
        candidate('internal', true),
    }, 'internal')
    info.skillcheck = skillcheckKey
    appendReasons(info.fallbacks, 'skillcheck', skillcheckReasons)

    local function merge(adapter, names)
        for _, name in ipairs(names) do
            if type(adapter and adapter[name]) == 'function' then bridge[name] = adapter[name] end
        end
    end
    merge(framework, { 'GetPlayerData' })
    merge(notify, { 'Notify' })
    merge(menu, { 'OpenMenu' })
    merge(progress, { 'Progress', 'CancelProgress' })
    merge(skillcheck, { 'SkillCheck' })

    bridge.GetAdapterSnapshot = function() return BridgeCore.Copy(info) end
    bridge.GetDiagnostics = bridge.GetAdapterSnapshot
    bridge.OpenMenu = bridge.OpenMenu or function(spec)
        local first = spec and spec.options and spec.options[1]
        if first and first.action then first.action(); return true end
        return false
    end

    local function register(spec)
        if target and target.RegisterInteractable then pcall(target.RegisterInteractable, spec) end
    end
    local function remove(id)
        if target and target.RemoveInteractable then pcall(target.RemoveInteractable, id) end
    end

    bridge.RegisterInteractable = function(spec)
        if type(spec) ~= 'table' or type(spec.id) ~= 'string' or spec.id == '' then return false end
        interactables[spec.id] = spec
        register(spec)
        return true
    end
    bridge.RemoveInteractable = function(id)
        if type(id) ~= 'string' then return false end
        interactables[id] = nil
        remove(id)
        return true
    end
    bridge.Target = target
    activeTarget = target
    info.capabilities = {
        framework = { playerData = type(bridge.GetPlayerData) == 'function' },
        target = { register = type(bridge.RegisterInteractable) == 'function', remove = type(bridge.RemoveInteractable) == 'function' },
        ui = { notify = type(bridge.Notify) == 'function', menu = type(bridge.OpenMenu) == 'function', progress = type(bridge.Progress) == 'function', skillcheck = type(bridge.SkillCheck) == 'function' },
    }
    return bridge, info
end

local function rebuild(reason)
    if rebuilding then return end
    rebuilding = true

    if not IsDuplicityVersion() and activeTarget then
        for id in pairs(interactables) do pcall(activeTarget.RemoveInteractable, id) end
    end

    local bridge, info
    if IsDuplicityVersion() then bridge, info = buildServer() else bridge, info = buildClient() end
    Bridge = bridge
    Bridge.AdapterInfo = BridgeCore.Copy(info)
    initialized = true

    if not IsDuplicityVersion() then
        for _, spec in pairs(interactables) do pcall(activeTarget.RegisterInteractable, spec) end
    end

    if reason then warn(('bridge rebuilt (%s): framework=%s inventory=%s target=%s notify=%s menu=%s progress=%s skillcheck=%s database=%s'):format(
        reason,
        tostring(info.framework),
        tostring(info.inventory),
        tostring(info.target),
        tostring(info.notify),
        tostring(info.menu),
        tostring(info.progress),
        tostring(info.skillcheck),
        tostring(info.database))) end
    for category, reasons in pairs(info.fallbacks or {}) do
        for _, message in ipairs(reasons) do
            warn(('bridge %s: %s'):format(category, message))
        end
    end
    if IsDuplicityVersion() and type(TriggerEvent) == 'function' then
        TriggerEvent('gnsh-blackout:server:bridgeChanged', BridgeCore.Copy(info))
    end
    rebuilding = false
end

rebuild('initial')
Bridge.Rebuild = rebuild

local function printDiagnostics(source)
    local info = Bridge.GetAdapterSnapshot and Bridge.GetAdapterSnapshot() or {}
    local line = ('framework=%s inventory=%s target=%s notify=%s menu=%s progress=%s skillcheck=%s database=%s'):format(
        tostring(info.framework), tostring(info.inventory), tostring(info.target), tostring(info.notify),
        tostring(info.menu), tostring(info.progress), tostring(info.skillcheck), tostring(info.database))
    print('[gnsh-blackout] bridge ' .. line)
    for category, reasons in pairs(info.fallbacks or {}) do
        for _, message in ipairs(reasons) do print(('[gnsh-blackout] bridge fallback %s: %s'):format(category, message)) end
    end
    if source and source ~= 0 and Bridge.Notify then
        if IsDuplicityVersion() then
            Bridge.Notify(source, 'Bridge durumu server konsoluna yazıldı.', 'info')
        else
            Bridge.Notify('Bridge durumu server konsoluna yazıldı.', 'info')
        end
    end
end

if type(RegisterCommand) == 'function' then
    RegisterCommand('blackoutbridge', function(source)
        printDiagnostics(source)
    end, false)
end

if type(AddEventHandler) == 'function' then
    if not IsDuplicityVersion() then
        AddEventHandler('gnsh-blackout:client:optionalBridgeReady', function(resourceName)
            if resourceName == 'ox_lib' and initialized then rebuild('optional_ready:ox_lib') end
        end)
    end
    AddEventHandler('onResourceStart', function(resourceName)
        if resourceName ~= currentResource() and watchedResources[resourceName] then rebuild('resource_start:' .. tostring(resourceName)) end
    end)
    AddEventHandler('onResourceStop', function(resourceName)
        if resourceName ~= currentResource() and watchedResources[resourceName] then rebuild('resource_stop:' .. tostring(resourceName)) end
    end)
end
