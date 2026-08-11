--[[
    tests/spec/zone_resolver_spec.lua

    Geometry tests for shared/zone_resolver.lua (spec §8, §9): polygon and
    radius containment, Z-range rejection, and custom-zone priority/
    overlap resolution.

    ZoneGeometry.Invalidate() is called before every ResolveCustomZone
    test because the module lazily caches its prepared zone list on first
    use — without invalidating, later tests would silently keep testing
    against the FIRST test's Config.Zones.
]]

-- ── PointInPolygon ───────────────────────────────────────────────────────

TEST('PointInPolygon: point inside a simple square', function()
    local square = { { x = 0, y = 0 }, { x = 0, y = 10 }, { x = 10, y = 10 }, { x = 10, y = 0 } }
    ASSERT_TRUE(ZoneGeometry.PointInPolygon({ x = 5, y = 5, z = 0 }, square))
end)

TEST('PointInPolygon: point outside a simple square', function()
    local square = { { x = 0, y = 0 }, { x = 0, y = 10 }, { x = 10, y = 10 }, { x = 10, y = 0 } }
    ASSERT_FALSE(ZoneGeometry.PointInPolygon({ x = 50, y = 50, z = 0 }, square))
end)

TEST('PointInPolygon: respects minZ/maxZ even when XY is inside', function()
    local square = { { x = 0, y = 0 }, { x = 0, y = 10 }, { x = 10, y = 10 }, { x = 10, y = 0 } }
    ASSERT_FALSE(ZoneGeometry.PointInPolygon({ x = 5, y = 5, z = 100 }, square, 0, 50))
    ASSERT_TRUE(ZoneGeometry.PointInPolygon({ x = 5, y = 5, z = 25 }, square, 0, 50))
end)

TEST('PointInPolygon: L-shaped (non-convex) polygon, point in the notch is outside', function()
    -- L-shape: full 10x10 square with the top-right 5x5 quadrant removed.
    local lshape = {
        { x = 0, y = 0 }, { x = 10, y = 0 }, { x = 10, y = 5 },
        { x = 5, y = 5 }, { x = 5, y = 10 }, { x = 0, y = 10 },
    }
    ASSERT_TRUE(ZoneGeometry.PointInPolygon({ x = 2, y = 2, z = 0 }, lshape), 'inside the L body')
    ASSERT_FALSE(ZoneGeometry.PointInPolygon({ x = 7, y = 7, z = 0 }, lshape), 'inside the removed notch')
end)

-- ── PointInRadius ────────────────────────────────────────────────────────

TEST('PointInRadius: inside radius', function()
    ASSERT_TRUE(ZoneGeometry.PointInRadius({ x = 3, y = 4, z = 0 }, { x = 0, y = 0 }, 10))
end)

TEST('PointInRadius: outside radius', function()
    ASSERT_FALSE(ZoneGeometry.PointInRadius({ x = 30, y = 40, z = 0 }, { x = 0, y = 0 }, 10))
end)

TEST('PointInRadius: exactly on the boundary counts as inside', function()
    ASSERT_TRUE(ZoneGeometry.PointInRadius({ x = 10, y = 0, z = 0 }, { x = 0, y = 0 }, 10))
end)

TEST('PointInRadius: respects Z range', function()
    ASSERT_FALSE(ZoneGeometry.PointInRadius({ x = 0, y = 0, z = 100 }, { x = 0, y = 0 }, 10, 0, 50))
end)

-- ── ResolveCustomZone ────────────────────────────────────────────────────

TEST('ResolveCustomZone: single polygon zone claims a point inside it', function()
    Config.Zones = {
        { id = 'z1', type = Constants.Resolver.POLYGON, gridId = 'grid_a',
          points = { { x = 0, y = 0 }, { x = 0, y = 10 }, { x = 10, y = 10 }, { x = 10, y = 0 } } },
    }
    ZoneGeometry.Invalidate()

    local gridId = ZoneGeometry.ResolveCustomZone({ x = 5, y = 5, z = 0 })
    ASSERT_EQ(gridId, 'grid_a')
end)

TEST('ResolveCustomZone: point outside every zone returns nil', function()
    Config.Zones = {
        { id = 'z1', type = Constants.Resolver.RADIUS, gridId = 'grid_a', center = { x = 0, y = 0 }, radius = 5 },
    }
    ZoneGeometry.Invalidate()

    local gridId = ZoneGeometry.ResolveCustomZone({ x = 1000, y = 1000, z = 0 })
    ASSERT_EQ(gridId, nil)
end)

TEST('ResolveCustomZone: overlapping zones, higher priority wins', function()
    Config.Zones = {
        { id = 'low', type = Constants.Resolver.RADIUS, gridId = 'grid_low', center = { x = 0, y = 0 }, radius = 100, priority = 1 },
        { id = 'high', type = Constants.Resolver.RADIUS, gridId = 'grid_high', center = { x = 0, y = 0 }, radius = 10, priority = 10 },
    }
    ZoneGeometry.Invalidate()

    -- Inside both circles — the higher-priority (smaller, more specific) zone should win.
    local gridId = ZoneGeometry.ResolveCustomZone({ x = 1, y = 1, z = 0 })
    ASSERT_EQ(gridId, 'grid_high')

    -- Inside only the larger, lower-priority circle.
    local gridId2 = ZoneGeometry.ResolveCustomZone({ x = 50, y = 0, z = 0 })
    ASSERT_EQ(gridId2, 'grid_low')
end)

TEST('ResolveCustomZone: equal priority, smaller area wins the tie-break', function()
    Config.Zones = {
        { id = 'big', type = Constants.Resolver.RADIUS, gridId = 'grid_big', center = { x = 0, y = 0 }, radius = 100 },
        { id = 'small', type = Constants.Resolver.RADIUS, gridId = 'grid_small', center = { x = 0, y = 0 }, radius = 10 },
    }
    ZoneGeometry.Invalidate()

    local gridId = ZoneGeometry.ResolveCustomZone({ x = 1, y = 1, z = 0 })
    ASSERT_EQ(gridId, 'grid_small')
end)

-- Leave Config.Zones empty for anything relying on it after this file.
Config.Zones = {}
ZoneGeometry.Invalidate()
