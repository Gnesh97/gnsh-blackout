--[[
    server/zone_resolver.lua

    Server-side geographic resolution (spec §50). Two-step pipeline, per
    Config.ResolverPriority:
        1. Explicit custom zone   (ZoneGeometry.ResolveCustomZone, exact)
        2. GTA native district    (AABB approximation, see shared/districts.lua
                                    header comment for why this is
                                    approximate and how to calibrate it)
        3. Config.DefaultGrid     (fail-open to "powered" if nil)

    This is the server-side half of the split described in
    shared/districts.lua — the client resolves districts via the
    GetNameOfZone() native (server/zone_resolver.lua has no such native
    available, hence the AABB table).
]]

ServerZone = {}

-- Smallest-volume-wins AABB district lookup (Districts.SortedByVolume is
-- pre-sorted ascending by volume at load time — see shared/districts.lua).
function ServerZone.ResolveDistrict(coords)
    if Metrics then Metrics.Inc('server.districtResolver.calls') end
    for _, district in ipairs(Districts.SortedByVolume) do
        if Utils.PointInAABB(coords, district.aabb.min, district.aabb.max) then
            return district.code
        end
    end
    return nil
end

-- Full pipeline: custom zone -> GTA district -> grid lookup -> default.
-- Returns gridId (or nil), and the resolved district code (or nil) for
-- diagnostics/debug output.
function ServerZone.ResolvePosition(coords)
    for _, resolverName in ipairs(Config.ResolverPriority) do
        if resolverName == 'custom_zone' then
            local gridId = ZoneGeometry.ResolveCustomZone(coords)
            if gridId then
                return gridId, nil
            end
        elseif resolverName == 'gta_native' then
            local district = ServerZone.ResolveDistrict(coords)
            if district then
                local gridId = GridManager.GetGridForDistrict(district)
                if gridId then
                    return gridId, district
                end
                -- District resolved but isn't wired to any grid — treat as
                -- unmanaged territory, not an error. Fall through to the
                -- next resolver / default.
            end
        end
    end

    return Config.DefaultGrid, nil
end

-- Convenience used directly by the IsPositionPowered() export.
function ServerZone.ResolveDistrictOnly(coords)
    local district = ServerZone.ResolveDistrict(coords)
    if district then return district end
    return nil
end
