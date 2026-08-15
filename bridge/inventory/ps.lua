-- ps-inventory adapter. Prefer server exports; fall back to a Player object
-- when ps-inventory is configured as a QBCore-compatible inventory.

if not IsDuplicityVersion() then return end

InventoryAdapters = InventoryAdapters or {}
InventoryAdapters.ps_inventory = {}
local A = InventoryAdapters.ps_inventory

local function exportCall(name, ...)
    local args = { ... }
    return pcall(function() return exports['ps-inventory'][name](table.unpack(args)) end)
end

function A.HasItem(source, item, amount)
    local ok, result = exportCall('GetItemByName', source, item)
    if ok and result then
        return (tonumber(result.amount or result.count) or 0) >= (amount or 1)
    end
    return false, 'ps-inventory item query unavailable'
end

function A.RemoveItem(source, item, amount)
    local ok, result = exportCall('RemoveItem', source, item, amount or 1)
    return ok and result ~= false or false
end

function A.AddItem(source, item, amount)
    local ok, result = exportCall('AddItem', source, item, amount or 1)
    return ok and result ~= false or false
end
