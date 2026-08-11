--[[
    bridge/inventory/ox_inventory.lua

    ox_inventory adapter (server-only — inventory operations are always
    server-authoritative). This server runs ox_inventory 2.45.1 with
    `inventory:framework "qb"` set, so this is the default pick.

    Not exercised by Phase 1-8 (no sabotage/repair item consumption yet —
    that's Phase 12-13), but wired now so the interface is stable and the
    later phases don't need a bridge migration.
]]

if not IsDuplicityVersion() then return end

InventoryAdapters = InventoryAdapters or {}
InventoryAdapters.ox_inventory = {}

local A = InventoryAdapters.ox_inventory

function A.HasItem(source, item, amount)
    amount = amount or 1
    local count = exports.ox_inventory:Search(source, 'count', item)
    return (count or 0) >= amount
end

function A.RemoveItem(source, item, amount)
    amount = amount or 1
    return exports.ox_inventory:RemoveItem(source, item, amount) == true
end

function A.AddItem(source, item, amount)
    amount = amount or 1
    return exports.ox_inventory:AddItem(source, item, amount) == true
end
