--[[
    client/zone_resolver.lua

    Client-side district resolution via the GetNameOfZone() native (spec
    §5) — the authoritative source of truth for "what GTA district is this
    point in" (unlike the server's AABB approximation, see
    shared/districts.lua header comment).
]]

ClientZone = {}

local loggedUnknown = {}

-- Returns the district code GetNameOfZone() resolved to. If the native
-- returns a code we don't have an entry for in shared/districts.lua, we
-- still return that raw code (callers may want it for /districtaudit
-- diagnostics) but log the gap exactly once per code so extending the
-- table is easy without spamming the console every poll tick.
function ClientZone.ResolveDistrict(coords)
    if Metrics then Metrics.Inc('client.districtResolver.calls') end
    local code = GetNameOfZone(coords.x, coords.y, coords.z)
    if not code or code == '' then
        return Districts.UNKNOWN_CODE
    end

    if not Districts.Exists(code) and not loggedUnknown[code] then
        loggedUnknown[code] = true
        print(('^3[gnsh-blackout] GetNameOfZone returned unmapped code "%s" — add it to shared/districts.lua if it matters for grid coverage^7'):format(code))
    end

    return code
end

-- Full client-side resolution pipeline (custom zone first, then native
-- district), mirroring server/zone_resolver.lua's ResolvePosition but
-- using the authoritative native instead of the AABB approximation.
function ClientZone.ResolvePosition(coords)
    for _, resolverName in ipairs(Config.ResolverPriority) do
        if resolverName == 'custom_zone' then
            local gridId = ZoneGeometry.ResolveCustomZone(coords)
            if gridId then return gridId, nil end
        elseif resolverName == 'gta_native' then
            local district = ClientZone.ResolveDistrict(coords)
            if district and district ~= Districts.UNKNOWN_CODE then
                return nil, district -- grid lookup happens client-side via GridIndex (Phase 4/7)
            end
        end
    end
    return nil, nil
end
