--[[
    bridge/inventory/none.lua

    No-inventory fallback. Fails closed: HasItem is always false, Add/
    RemoveItem always fail. Used when Config.Bridge.inventory = 'none' or
    auto-detection finds no supported inventory resource running.
]]

if not IsDuplicityVersion() then return end

InventoryAdapters = InventoryAdapters or {}
InventoryAdapters.none = {}

local A = InventoryAdapters.none

function A.HasItem(_source, _item, _amount)
    return false
end

function A.RemoveItem(_source, _item, _amount)
    return false
end

function A.AddItem(_source, _item, _amount)
    return false
end
