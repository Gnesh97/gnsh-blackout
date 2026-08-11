--[[
    client/visual/ownership.lua

    Visual asset ownership / reference counting (spec §27). Problem this
    solves: if two grids both apply an effect to the same shared asset,
    the first grid's cleanup must NOT remove it while the second grid
    still needs it. An asset is only actually removed when its refCount
    reaches 0.

    Phase 8 only has one asset (the native artificial-lights toggle,
    conceptually "owned" by whichever grid is currently blacked out for
    the local player) and only one owner at a time is realistically
    possible client-side (a player is only ever in one grid), but the
    API is written for the N-owner case now so Phase 16's hybrid visual
    expansion doesn't need an ownership-model migration.
]]

VisualOwnership = {}

local assets = {} -- [assetId] = { refCount = n, owners = { [ownerId] = true } }

-- Registers interest in `assetId` from `ownerId`. Returns true if this
-- call transitioned the asset from unowned -> owned (i.e. the caller
-- should actually apply the effect now); false if some other owner
-- already holds it (the effect is already applied, do nothing).
function VisualOwnership.Acquire(assetId, ownerId)
    local entry = assets[assetId]
    if not entry then
        entry = { refCount = 0, owners = {} }
        assets[assetId] = entry
    end

    if entry.owners[ownerId] then
        return false -- already held by this exact owner — idempotent, no-op
    end

    entry.owners[ownerId] = true
    entry.refCount = entry.refCount + 1

    return entry.refCount == 1
end

-- Releases `ownerId`'s interest in `assetId`. Returns true if this call
-- transitioned refCount to 0 (i.e. the caller should actually remove the
-- effect now); false if other owners still hold it.
function VisualOwnership.Release(assetId, ownerId)
    local entry = assets[assetId]
    if not entry then
        return false -- asset was never held at all — normal, no-op
    end

    if not entry.owners[ownerId] then
        -- Asset IS held, just not by this owner — suspicious enough to
        -- log (a caller mismatched an acquire/release pair somewhere)
        -- but still a safe no-op, never an underflow into someone else's
        -- hold.
        print(('^3[gnsh-blackout] VisualOwnership.Release: "%s" tried to release "%s" it never acquired (current refCount=%d)^7'):format(tostring(ownerId), tostring(assetId), entry.refCount))
        return false
    end

    entry.owners[ownerId] = nil
    entry.refCount = math.max(0, entry.refCount - 1)

    if entry.refCount == 0 then
        assets[assetId] = nil
        return true
    end

    return false
end

function VisualOwnership.IsHeld(assetId)
    local entry = assets[assetId]
    return entry ~= nil and entry.refCount > 0
end

function VisualOwnership.GetRefCount(assetId)
    local entry = assets[assetId]
    return entry and entry.refCount or 0
end

-- Hard reset for resource stop (spec §61) — drops all ownership
-- bookkeeping without going through Release() for each owner, since the
-- caller (client/main.lua) is about to force-remove every effect anyway.
function VisualOwnership.Reset()
    assets = {}
end

-- Read-only snapshot for /visualdebug (Phase 16) — a list of
-- { assetId, refCount, owners = {ownerId, ...} }, sorted by assetId so
-- output is stable across calls. Never returns a reference into the
-- internal `assets` table.
function VisualOwnership.Debug()
    local list = {}
    for assetId, entry in pairs(assets) do
        local owners = {}
        for ownerId in pairs(entry.owners) do
            owners[#owners + 1] = tostring(ownerId)
        end
        table.sort(owners)
        list[#list + 1] = { assetId = assetId, refCount = entry.refCount, owners = owners }
    end
    table.sort(list, function(a, b) return a.assetId < b.assetId end)
    return list
end
