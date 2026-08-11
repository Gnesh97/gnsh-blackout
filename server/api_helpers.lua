--[[
    server/api_helpers.lua

    Pure helpers for the public API.  The API crosses a resource boundary, so
    every table returned from it must be detached from the runtime cache.
    Keeping these helpers free of FiveM natives also makes the copy and input
    validation contract unit-testable with the framework-free harness.
]]

ApiHelpers = {}

function ApiHelpers.DeepCopy(value, seen)
    if type(value) ~= 'table' then return value end

    seen = seen or {}
    if seen[value] then return seen[value] end

    local copy = {}
    seen[value] = copy
    for key, child in pairs(value) do
        copy[ApiHelpers.DeepCopy(key, seen)] = ApiHelpers.DeepCopy(child, seen)
    end

    return copy
end

function ApiHelpers.NormalizeIdentifier(value)
    if type(value) ~= 'string' then return nil end
    local normalized = value:match('^%s*(.-)%s*$')
    if normalized == '' then return nil end
    return normalized
end

function ApiHelpers.NormalizeDistrict(value)
    local normalized = ApiHelpers.NormalizeIdentifier(value)
    return normalized and string.upper(normalized) or nil
end

local function finiteNumber(value)
    return type(value) == 'number'
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function readCoordinate(coords, name, index)
    local ok, value = pcall(function() return coords[name] end)
    if ok and value ~= nil then return value end

    ok, value = pcall(function() return coords[index] end)
    return ok and value or nil
end

function ApiHelpers.ValidateCoordinates(coords)
    if coords == nil then
        return false, 'coordinates must be a table or vector3'
    end

    local x = readCoordinate(coords, 'x', 1)
    local y = readCoordinate(coords, 'y', 2)
    local z = readCoordinate(coords, 'z', 3)
    if not finiteNumber(x) or not finiteNumber(y) or not finiteNumber(z) then
        return false, 'coordinates require finite numeric x, y and z values'
    end

    return true
end

function ApiHelpers.CopyCoordinates(coords)
    local x = readCoordinate(coords, 'x', 1)
    local y = readCoordinate(coords, 'y', 2)
    local z = readCoordinate(coords, 'z', 3)
    return { x = x, y = y, z = z }
end
