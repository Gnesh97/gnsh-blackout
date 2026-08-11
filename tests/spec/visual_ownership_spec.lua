--[[
    tests/spec/visual_ownership_spec.lua

    client/visual/ownership.lua (spec §27, Phase 16) touches zero FiveM
    natives — plain tables and math.max — so it's genuinely unit-testable,
    unlike the adapters around it. Covers the edge cases spec §27's
    "shared asset" problem actually depends on: acquire/release 0->1/1->0
    transitions, double-acquire idempotency, release-without-acquire
    safety, multi-owner ref-counting, and Reset().
]]

TEST('first Acquire on a fresh asset transitions 0 -> 1 (returns true)', function()
    VisualOwnership.Reset()
    local shouldApply = VisualOwnership.Acquire('asset_a', 'owner_1')
    ASSERT_TRUE(shouldApply, 'first acquire must signal the caller to actually apply the effect')
    ASSERT_TRUE(VisualOwnership.IsHeld('asset_a'))
    ASSERT_EQ(VisualOwnership.GetRefCount('asset_a'), 1)
end)

TEST('second Acquire by a DIFFERENT owner does not re-signal apply (already held)', function()
    VisualOwnership.Reset()
    VisualOwnership.Acquire('asset_a', 'owner_1')
    local shouldApply = VisualOwnership.Acquire('asset_a', 'owner_2')
    ASSERT_FALSE(shouldApply, 'second owner must not re-trigger apply — asset is already applied')
    ASSERT_EQ(VisualOwnership.GetRefCount('asset_a'), 2)
end)

TEST('re-Acquire by the SAME owner is idempotent (no refcount inflation)', function()
    VisualOwnership.Reset()
    VisualOwnership.Acquire('asset_a', 'owner_1')
    local shouldApply = VisualOwnership.Acquire('asset_a', 'owner_1')
    ASSERT_FALSE(shouldApply, 'same owner acquiring twice must be a no-op the second time')
    ASSERT_EQ(VisualOwnership.GetRefCount('asset_a'), 1, 'refcount must not inflate from a duplicate acquire')
end)

TEST('Release by one of two owners does not remove the asset (refcount still > 0)', function()
    VisualOwnership.Reset()
    VisualOwnership.Acquire('asset_a', 'owner_1')
    VisualOwnership.Acquire('asset_a', 'owner_2')
    local shouldRemove = VisualOwnership.Release('asset_a', 'owner_1')
    ASSERT_FALSE(shouldRemove, 'other owner still holds the asset — must not signal removal')
    ASSERT_TRUE(VisualOwnership.IsHeld('asset_a'))
    ASSERT_EQ(VisualOwnership.GetRefCount('asset_a'), 1)
end)

TEST('Release by the LAST owner transitions 1 -> 0 (returns true, asset dropped)', function()
    VisualOwnership.Reset()
    VisualOwnership.Acquire('asset_a', 'owner_1')
    VisualOwnership.Acquire('asset_a', 'owner_2')
    VisualOwnership.Release('asset_a', 'owner_1')
    local shouldRemove = VisualOwnership.Release('asset_a', 'owner_2')
    ASSERT_TRUE(shouldRemove, 'last owner releasing must signal the caller to actually remove the effect')
    ASSERT_FALSE(VisualOwnership.IsHeld('asset_a'))
    ASSERT_EQ(VisualOwnership.GetRefCount('asset_a'), 0)
end)

TEST('Release without a prior Acquire is a safe no-op (never underflows)', function()
    VisualOwnership.Reset()
    local shouldRemove = VisualOwnership.Release('asset_never_acquired', 'owner_1')
    ASSERT_FALSE(shouldRemove)
    ASSERT_EQ(VisualOwnership.GetRefCount('asset_never_acquired'), 0)
end)

TEST('Release by a non-owner on a held asset is a safe no-op (does not strand real owners)', function()
    VisualOwnership.Reset()
    VisualOwnership.Acquire('asset_a', 'owner_1')
    local shouldRemove = VisualOwnership.Release('asset_a', 'owner_2') -- owner_2 never acquired it
    ASSERT_FALSE(shouldRemove)
    ASSERT_TRUE(VisualOwnership.IsHeld('asset_a'), 'the real owner must still hold the asset')
    ASSERT_EQ(VisualOwnership.GetRefCount('asset_a'), 1)
end)

TEST('double Release by the same owner (release-after-release) is a safe no-op', function()
    VisualOwnership.Reset()
    VisualOwnership.Acquire('asset_a', 'owner_1')
    VisualOwnership.Release('asset_a', 'owner_1')
    local shouldRemove = VisualOwnership.Release('asset_a', 'owner_1')
    ASSERT_FALSE(shouldRemove, 'releasing an already-released owner must not signal a second removal')
end)

TEST('separate assets track ownership independently', function()
    VisualOwnership.Reset()
    VisualOwnership.Acquire('asset_a', 'owner_1')
    ASSERT_FALSE(VisualOwnership.IsHeld('asset_b'), 'acquiring asset_a must not affect asset_b')
    ASSERT_EQ(VisualOwnership.GetRefCount('asset_b'), 0)
end)

TEST('Reset() drops all assets/owners unconditionally', function()
    VisualOwnership.Reset()
    VisualOwnership.Acquire('asset_a', 'owner_1')
    VisualOwnership.Acquire('asset_b', 'owner_1')
    VisualOwnership.Reset()
    ASSERT_FALSE(VisualOwnership.IsHeld('asset_a'))
    ASSERT_FALSE(VisualOwnership.IsHeld('asset_b'))
    ASSERT_EQ(VisualOwnership.GetRefCount('asset_a'), 0)
end)
