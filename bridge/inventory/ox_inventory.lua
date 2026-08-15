-- ox_inventory server adapter. No ox_inventory import is required; every
-- call is guarded and selected only while the resource is running.

if not IsDuplicityVersion() then return end

InventoryAdapters = InventoryAdapters or {}
InventoryAdapters.ox_inventory = {}

local A = InventoryAdapters.ox_inventory

local function call(method, source, item, amount)
    local ok, result = pcall(function()
        if method == 'Search' then
            return exports.ox_inventory:Search(source, 'count', item)
        end
        if method == 'RemoveItem' then
            return exports.ox_inventory:RemoveItem(source, item, amount)
        end
        if method == 'AddItem' then
            return exports.ox_inventory:AddItem(source, item, amount)
        end
        return false, 'unsupported ox_inventory method'
    end)
    return ok, result
end

function A.HasItem(source, item, amount)
    local ok, count = call('Search', source, item, amount)
    if not ok then return false, 'ox_inventory search failed' end
    return (tonumber(count) or 0) >= (amount or 1)
end

function A.RemoveItem(source, item, amount)
    local ok, result = call('RemoveItem', source, item, amount or 1)
    return ok and result == true or false
end

function A.AddItem(source, item, amount)
    local ok, result = call('AddItem', source, item, amount or 1)
    return ok and result == true or false
end
