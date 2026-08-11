--[[
    shared/zone_resolver.lua

    Framework-free geometry for custom zones (spec §4, §8, §9): polygon and
    radius containment tests, plus the shared "which custom zone (if any)
    claims this point" lookup used identically by client and server.

    This file does NOT know about GTA native districts — that split lives
    in client/zone_resolver.lua (native GetNameOfZone) and
    server/zone_resolver.lua (AABB approximation), both of which call into
    ZoneGeometry.ResolveCustomZone() first per the resolver priority order
    (Config.ResolverPriority, spec §9).
]]

ZoneGeometry = {}

local preparedZones = nil -- built lazily, once, from Config.Zones

-- Ray-casting point-in-polygon test (2D, then a Z range check). `points`
-- is an array of {x=, y=} and does not need to be closed (first point is
-- implicitly connected back to the last).
function ZoneGeometry.PointInPolygon(point, poly, minZ, maxZ)
    if minZ and point.z < minZ then return false end
    if maxZ and point.z > maxZ then return false end

    local inside = false
    local n = #poly
    local j = n
    for i = 1, n do
        local pi, pj = poly[i], poly[j]
        if ((pi.y > point.y) ~= (pj.y > point.y)) and
            (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x) then
            inside = not inside
        end
        j = i
    end
    return inside
end

function ZoneGeometry.PointInRadius(point, center, radius, minZ, maxZ)
    if minZ and point.z < minZ then return false end
    if maxZ and point.z > maxZ then return false end
    return Utils.Distance2D(point, center) <= radius
end

-- Precompute each polygon's AABB so we can cheaply reject before running
-- the more expensive ray-cast, and sort by ascending priority-then-area so
-- ResolveCustomZone() can stop at the first (highest priority) match.
local function prepareZones()
    if preparedZones then return preparedZones end
    preparedZones = {}

    for _, zone in ipairs(Config.Zones or {}) do
        local prepared = {
            id = zone.id,
            type = zone.type,
            gridId = zone.gridId,
            minZ = zone.minZ,
            maxZ = zone.maxZ,
            priority = zone.priority or 0,
        }

        if zone.type == Constants.Resolver.POLYGON then
            prepared.points = zone.points
            local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
            for _, p in ipairs(zone.points) do
                minX = math.min(minX, p.x)
                maxX = math.max(maxX, p.x)
                minY = math.min(minY, p.y)
                maxY = math.max(maxY, p.y)
            end
            prepared.aabb = { minX = minX, minY = minY, maxX = maxX, maxY = maxY }
        elseif zone.type == Constants.Resolver.RADIUS then
            prepared.center = zone.center
            prepared.radius = zone.radius
            prepared.aabb = {
                minX = zone.center.x - zone.radius,
                maxX = zone.center.x + zone.radius,
                minY = zone.center.y - zone.radius,
                maxY = zone.center.y + zone.radius,
            }
        end

        preparedZones[#preparedZones + 1] = prepared
    end

    -- Higher priority first; ties broken by smaller bounding area (more
    -- specific zone wins), mirroring the district AABB tie-break rule.
    table.sort(preparedZones, function(a, b)
        if a.priority ~= b.priority then
            return a.priority > b.priority
        end
        local areaA = (a.aabb.maxX - a.aabb.minX) * (a.aabb.maxY - a.aabb.minY)
        local areaB = (b.aabb.maxX - b.aabb.minX) * (b.aabb.maxY - b.aabb.minY)
        return areaA < areaB
    end)

    return preparedZones
end

-- Explicit custom zone lookup (spec §9 priority step 1). Returns the
-- zone's gridId, or nil if no custom zone claims this point.
function ZoneGeometry.ResolveCustomZone(coords)
    local zones = prepareZones()

    for _, zone in ipairs(zones) do
        -- Cheap AABB pre-filter before the more expensive containment test.
        if coords.x >= zone.aabb.minX and coords.x <= zone.aabb.maxX
            and coords.y >= zone.aabb.minY and coords.y <= zone.aabb.maxY then
            local hit = false
            if zone.type == Constants.Resolver.POLYGON then
                hit = ZoneGeometry.PointInPolygon(coords, zone.points, zone.minZ, zone.maxZ)
            elseif zone.type == Constants.Resolver.RADIUS then
                hit = ZoneGeometry.PointInRadius(coords, zone.center, zone.radius, zone.minZ, zone.maxZ)
            end
            if hit then
                return zone.gridId, zone.id
            end
        end
    end

    return nil
end

-- Called by debug/reload tooling after Config.Zones is edited at runtime
-- (e.g. /reloadvisual-adjacent tooling in later phases). Not required for
-- Phase 1-8's static config but cheap to provide now.
function ZoneGeometry.Invalidate()
    preparedZones = nil
end
