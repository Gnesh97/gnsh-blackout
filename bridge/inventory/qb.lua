-- Legacy qb-inventory / framework-compatible item adapter.

if not IsDuplicityVersion() then return end

InventoryAdapters = InventoryAdapters or {}
InventoryAdapters.qb_inventory = {}
InventoryAdapters.qb = InventoryAdapters.qb_inventory -- old internal key

local A = InventoryAdapters.qb_inventory

local function player(source)
    local framework = FrameworkAdapters and FrameworkAdapters.qbcore
    return framework and framework.GetPlayer and framework.GetPlayer(source) or nil
end

function A.HasItem(source, item, amount)
    local p = player(source)
    local fn = p and p.Functions and p.Functions.GetItemByName
    local entry = type(fn) == 'function' and fn(item) or nil
    if not entry then return false, 'item not found' end
    return (tonumber(entry.amount or entry.count) or 0) >= (amount or 1)
end

function A.RemoveItem(source, item, amount)
    local p = player(source)
    local fn = p and p.Functions and p.Functions.RemoveItem
    if type(fn) ~= 'function' then return false, 'qb-inventory remove unavailable' end
    local ok, result = pcall(fn, item, amount or 1)
    return ok and result ~= false or false
end

function A.AddItem(source, item, amount)
    local p = player(source)
    local fn = p and p.Functions and p.Functions.AddItem
    if type(fn) ~= 'function' then return false, 'qb-inventory add unavailable' end
    local ok, result = pcall(fn, item, amount or 1)
    return ok and result ~= false or false
end

