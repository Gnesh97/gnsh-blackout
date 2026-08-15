-- qs-inventory adapter. Export names differ between releases; supported
-- variants are tried in order and all failures return a safe false result.

if not IsDuplicityVersion() then return end

InventoryAdapters = InventoryAdapters or {}
InventoryAdapters.qs_inventory = {}
local A = InventoryAdapters.qs_inventory

local function exportCall(names, ...)
    local args = { ... }
    for _, name in ipairs(names) do
        local ok, result = pcall(function() return exports['qs-inventory'][name](table.unpack(args)) end)
        if ok then return true, result end
    end
    return false, nil
end

function A.HasItem(source, item, amount)
    local ok, result = exportCall({ 'GetItemTotalAmount', 'GetItemCount' }, source, item)
    if not ok then return false, 'qs-inventory item query unavailable' end
    if type(result) == 'table' then result = result.amount or result.count end
    return (tonumber(result) or 0) >= (amount or 1)
end

function A.RemoveItem(source, item, amount)
    local ok, result = exportCall({ 'RemoveItem' }, source, item, amount or 1)
    return ok and result ~= false or false
end

function A.AddItem(source, item, amount)
    local ok, result = exportCall({ 'AddItem' }, source, item, amount or 1)
    return ok and result ~= false or false
end
