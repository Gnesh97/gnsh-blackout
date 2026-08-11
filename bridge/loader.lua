--[[
    bridge/loader.lua

    Assembles the final `Bridge` global from whichever adapters got
    registered into FrameworkAdapters / InventoryAdapters / TargetAdapters
    by the files loaded before this one (see fxmanifest.lua — this file is
    listed LAST among bridge/* entries).

    Auto-detection uses GetResourceState(), which is safe to call even if
    the resource in question hasn't started yet (returns 'missing' or
    'stopped' rather than erroring) — this resource has no hard
    `dependency` on qb-core/ox_lib/ox_inventory/qb-target (RULE 8), so
    start-order inside [standalone]/[qb] is not guaranteed and this must
    tolerate any of them being absent or starting after gnsh-blackout.

    NOTE: this file is a shared_script, loaded on BOTH sides, but
    server/logging.lua (the `Log` global) is server_scripts only — so this
    file must not assume `Log` exists. It uses a tiny local `warn()`
    wrapped around `print` instead, and only calls the real `Log.event`
    from inside the server-only branch below.

    Bridge.* surface (spec §55, §56):
        Bridge.GetPlayer(source)            -- server
        Bridge.GetJob(source)               -- server
        Bridge.HasPermission(source, group) -- server
        Bridge.Notify(...)                  -- server: (source, msg, type) | client: (msg, type)
        Bridge.HasItem(source, item, amt)   -- server
        Bridge.RemoveItem(source, item, amt)-- server
        Bridge.AddItem(source, item, amt)   -- server
        Bridge.RegisterInteractable(spec)   -- client
        Bridge.RemoveInteractable(id)       -- client
]]

Bridge = {}

local function warn(msg)
    print(('^3[gnsh-blackout] %s^7'):format(msg))
end

local function resourceRunning(name)
    return GetResourceState(name) == 'started'
end

local function resolveFrameworkKey()
    local pref = Config.Bridge.framework
    if pref and pref ~= 'auto' then return pref end
    if resourceRunning('qb-core') then return 'qbcore' end
    return 'standalone'
end

local function resolveInventoryKey()
    local pref = Config.Bridge.inventory
    if pref and pref ~= 'auto' then return pref end
    if resourceRunning('ox_inventory') then return 'ox_inventory' end
    if resourceRunning('qb-inventory') then return 'qb' end
    return 'none'
end

local function resolveTargetKey()
    local pref = Config.Bridge.target
    if pref and pref ~= 'auto' then return pref end
    if resourceRunning('qb-target') and GetConvar('UseTarget', 'false') == 'true' then
        return 'qb-target'
    end
    if resourceRunning('ox_lib') and _G.lib and _G.lib.points then return 'textui' end
    if resourceRunning('qb-target') then return 'qb-target' end
    return 'standalone'
end

local function mergeInto(target, source, label)
    if not source then
        warn(('bridge adapter "%s" produced no functions — falling back to no-op stubs'):format(label))
        return
    end
    for k, v in pairs(source) do
        target[k] = v
    end
end

if IsDuplicityVersion() then
    -- ── Server assembly ─────────────────────────────────────────────────
    local frameworkKey = resolveFrameworkKey()
    local inventoryKey = resolveInventoryKey()

    mergeInto(Bridge, FrameworkAdapters and FrameworkAdapters[frameworkKey], 'framework:' .. frameworkKey)
    mergeInto(Bridge, InventoryAdapters and InventoryAdapters[inventoryKey], 'inventory:' .. inventoryKey)

    Log.event(Constants.LogEvent.RESOURCE_STARTED, {
        framework = frameworkKey,
        inventory = inventoryKey,
    })
else
    -- ── Client assembly ─────────────────────────────────────────────────
    local frameworkKey = resolveFrameworkKey()
    local targetKey = resolveTargetKey()

    mergeInto(Bridge, FrameworkAdapters and FrameworkAdapters[frameworkKey], 'framework:' .. frameworkKey)
    -- Always merge standalone target adapter first as guaranteed fallback
    if TargetAdapters and TargetAdapters.standalone then
        mergeInto(Bridge, TargetAdapters.standalone, 'target:standalone')
    end
    if targetKey ~= 'standalone' then
        mergeInto(Bridge, TargetAdapters and TargetAdapters[targetKey], 'target:' .. targetKey)
    end
end
