-- oxmysql export adapter. Uses documented *_async aliases, so no
-- @oxmysql/lib/MySQL.lua import or resource dependency is required.

if not IsDuplicityVersion() then return end
DatabaseAdapters = DatabaseAdapters or {}
DatabaseAdapters.oxmysql = {}
local A = DatabaseAdapters.oxmysql

local function available()
    return type(GetResourceState) == 'function' and GetResourceState('oxmysql') == 'started'
end

function A.Available() return available() end

function A.Query(query, params)
    if not available() then return nil, 'oxmysql unavailable' end
    local ok, result = pcall(function()
        return exports.oxmysql:query_async(query, params or {})
    end)
    return ok and result or nil, ok and nil or result
end

function A.Insert(query, params)
    if not available() then return nil, 'oxmysql unavailable' end
    local ok, result = pcall(function()
        return exports.oxmysql:insert_async(query, params or {})
    end)
    return ok and result or nil, ok and nil or result
end

function A.Update(query, params)
    if not available() then return nil, 'oxmysql unavailable' end
    local ok, result = pcall(function()
        return exports.oxmysql:update_async(query, params or {})
    end)
    return ok and result or nil, ok and nil or result
end

