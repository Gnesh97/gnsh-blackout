--[[
    shared/utilities.lua

    Small dependency-free helpers used across shared/client/server code.
    Nothing here touches FiveM natives, so this file (and everything it
    depends on) can be loaded and unit-tested under a plain Lua 5.4
    interpreter — see tests/run.lua.
]]

Utils = {}

function Utils.Clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

function Utils.Round(value, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(value * mult + 0.5) / mult
end

-- Damage (0-100) -> Condition enum, per spec §14 boundaries defined in
-- shared/constants.lua (Constants.DamageThresholds).
function Utils.DamageToCondition(damage)
    damage = Utils.Clamp(damage or 0, 0, 100)
    for _, bracket in ipairs(Constants.DamageThresholds) do
        if damage <= bracket.max then
            return bracket.condition
        end
    end
    return Constants.Condition.DESTROYED
end

-- Guards a static config/enum table against accidental new-key writes
-- (typos creating a bogus state that's silently accepted elsewhere).
--
-- NOTE: Lua 5.4 removed the __pairs metamethod, so this intentionally does
-- NOT return an opaque read-only proxy — that would silently break
-- pairs()/ipairs() iteration for every caller that walks Districts/Grids/
-- Constants.*. Instead it attaches __newindex directly to the real table:
-- new keys are rejected, but reassigning an *existing* key is still
-- possible. That's an accepted trade-off for a defensive guard, not a
-- security boundary.
function Utils.FreezeShape(tbl)
    return setmetatable(tbl, {
        __newindex = function(_, key)
            error(('attempt to add new key "%s" to a frozen table'):format(tostring(key)), 2)
        end,
    })
end

function Utils.TableCount(tbl)
    local n = 0
    for _ in pairs(tbl) do n = n + 1 end
    return n
end

-- Shallow copy — used when handing out a table that must not let the
-- caller mutate our internal state (e.g. GetGridState() exports).
function Utils.ShallowCopy(tbl)
    local copy = {}
    for k, v in pairs(tbl) do copy[k] = v end
    return copy
end

function Utils.Distance2D(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

function Utils.Distance3D(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- True if `point` (a {x,y,z} or vec3-like table) lies within the axis
-- aligned box described by `min`/`max` (also {x,y,z}). Used by both the
-- district AABB lookup (Phase 2) and the custom-zone bounding-box
-- pre-filter (Phase 3).
function Utils.PointInAABB(point, min, max)
    return point.x >= min.x and point.x <= max.x
        and point.y >= min.y and point.y <= max.y
        and point.z >= min.z and point.z <= max.z
end

-- Volume of an AABB — used to rank overlapping district boxes so the
-- smallest (most specific) containing box wins (see shared/districts.lua
-- header comment and server/zone_resolver.lua).
function Utils.AABBVolume(min, max)
    return math.abs(max.x - min.x) * math.abs(max.y - min.y) * math.abs(max.z - min.z)
end

-- Simple leading/trailing whitespace trim, used by config validation
-- error messages and debug command argument parsing.
function Utils.Trim(str)
    return (str:gsub('^%s*(.-)%s*$', '%1'))
end
