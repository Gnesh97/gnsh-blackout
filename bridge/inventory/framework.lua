-- Uses active framework inventory methods when no dedicated inventory is
-- installed. Loader sets ActiveFrameworkAdapter before selecting this file.

if not IsDuplicityVersion() then return end

InventoryAdapters = InventoryAdapters or {}
InventoryAdapters.framework = {}

local A = InventoryAdapters.framework

local function active()
    return ActiveFrameworkAdapter
end

function A.HasItem(source, item, amount)
    local adapter = active()
    if not adapter or type(adapter.HasItem) ~= 'function' then return false, 'framework inventory unavailable' end
    return adapter.HasItem(source, item, amount)
end

function A.RemoveItem(source, item, amount)
    local adapter = active()
    if not adapter or type(adapter.RemoveItem) ~= 'function' then return false, 'framework inventory unavailable' end
    return adapter.RemoveItem(source, item, amount)
end

function A.AddItem(source, item, amount)
    local adapter = active()
    if not adapter or type(adapter.AddItem) ~= 'function' then return false, 'framework inventory unavailable' end
    return adapter.AddItem(source, item, amount)
end

