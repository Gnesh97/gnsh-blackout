--[[
    client/visual/manager.lua

    Decides WHEN to apply/remove the visual layer, and delegates the HOW
    to the adapter (client/visual/native_blackout.lua). This is the
    "district-based client gating" logic (spec §22): the only signal that
    matters is "is the district I currently care about (my current
    district, or the district I just entered) powered".

    Everything reacts to a single local event, 'infra:powerStateChanged'
    (fired by client/main.lua) — that one event already covers every case
    that matters:
      - startup / late join: fired once with whatever is already published
        for the player's current district (spec §32 — no flicker replay).
      - real power change on the player's current district: fired by the
        StateBag change handler.
      - district transition: fired by client/main.lua re-reading
        GlobalState for the newly entered district, since nothing
        "changed" server-side when a player merely walks between two
        districts.

    Ownership (spec §27) is routed through VisualOwnership — Phase 18
    keys it by DISTRICT id now, not grid id (see `heldByDistrict` below):
    before the feeder layer a district's power was always identical to
    its grid's, so gridId worked as the ownership key too. Now two
    districts under the same grid can legitimately differ (spec §18.7),
    so gating on gridId would treat them as the same owner and silently
    skip re-applying/removing the visual when walking between them.
    `gridId` is still read off the payload, but ONLY to resolve which
    visual PROFILE to use (spec §26/§28 — profiles are still grid-owned).

    TRANSITIONS (Phase 15): applying/removing the visual no longer calls
    NativeBlackout directly — it goes through client/visual/transition.lua
    so a real state change plays the spec §30/§31 flicker sequence while
    startup/late-join/district-transition snap instantly (spec §32, never
    replay). Which one happens is decided by `state.instant` on the
    'infra:powerStateChanged' payload — client/main.lua sets it true for
    the startup/late-join/district-transition paths and false for a
    genuine live StateBag change, which is the ONLY thing this file needs
    to check; it doesn't need to know WHY.
]]

VisualManager = {}

local ASSET_ID = 'native_blackout'
local heldByDistrict = nil
local heldByProfile = nil

local function safeHybridApply(profile, enabled)
    if not profile or profile.mode ~= Constants.VisualMode.HYBRID then return end
    local ok = pcall(VisualHybrid.Apply, profile, enabled)
    if not ok and Metrics then Metrics.Inc('client.visual.hybridFailure') end
end

-- A debug preview or an interrupted sequence can touch the native adapter
-- without creating a VisualOwnership holder. Every new powered/missing
-- snapshot must still be able to clean that stray native state, otherwise
-- VisualOwnership can report zero owners while the world remains blacked
-- out (Phase 20 transition cancellation contract).
local function forceRemoveStrayNative(profile)
    if NativeBlackout.IsApplied() then
        local affectVehicles = profile and profile.nativeBlackout and profile.nativeBlackout.affectVehicles
        Transition.ForceSync(false, affectVehicles)
    end
    ClientState.AppliedNativeBlackout = NativeBlackout.IsApplied()
end

local function releaseCurrentHold(instant, preserveNative)
    if not heldByDistrict then return end
    local shouldRemove = VisualOwnership.Release(ASSET_ID, heldByDistrict)
    local profile = heldByProfile
    heldByDistrict = nil
    heldByProfile = nil

    if not shouldRemove or preserveNative then return end

    safeHybridApply(profile, false)

    local affectVehicles = profile and profile.nativeBlackout and profile.nativeBlackout.affectVehicles
    if instant then
        Transition.ForceSync(false, affectVehicles)
        ClientState.AppliedNativeBlackout = NativeBlackout.IsApplied()
    else
        Transition.PlayRecovery(profile or {}, function()
            ClientState.AppliedNativeBlackout = NativeBlackout.IsApplied()
        end)
    end
end

local function acquireHold(districtId, profile, instant)
    local shouldApply = VisualOwnership.Acquire(ASSET_ID, districtId)
    heldByDistrict = districtId
    heldByProfile = profile

    if not shouldApply then return end

    safeHybridApply(profile, true)

    local affectVehicles = profile.nativeBlackout and profile.nativeBlackout.affectVehicles
    if instant then
        Transition.ForceSync(true, affectVehicles)
        ClientState.AppliedNativeBlackout = NativeBlackout.IsApplied()
    else
        Transition.PlayBlackout(profile, function()
            ClientState.AppliedNativeBlackout = NativeBlackout.IsApplied()
        end)
    end
end

AddEventHandler('infra:powerStateChanged', function(state)
    local districtId = state.districtId
    local gridId = state.gridId
    local powered = state.powered
    local instant = state.instant == true

    -- Phase 20 contract: every new state invalidates an older async
    -- sequence before any ownership/profile decision is made. ForceSync and
    -- Play* also advance the token, but this explicit cancel covers the
    -- invalid/missing-state paths where neither one would otherwise run.
    Transition.Cancel()

    if not districtId or not gridId then
        releaseCurrentHold(true)
        forceRemoveStrayNative()
        ClientState.CurrentVisualProfile = nil
        return
    end

    local profileName, profile = VisualProfiles.Resolve(districtId, gridId)

    if not profile then
        -- No supported visual profile for this grid — nothing to apply.
        -- (Phase 8 only ships NATIVE_CLIENT_GATE; other modes are
        -- reserved enum values, see shared/constants.lua.)
        releaseCurrentHold(true)
        forceRemoveStrayNative()
        ClientState.CurrentVisualProfile = nil
        return
    end

    if heldByDistrict and heldByDistrict ~= districtId then
        -- Native blackout is one shared client asset. When entering another
        -- blackout district, transfer ownership without removing the asset
        -- in between; otherwise ForceSync(false) creates a visible flash.
        releaseCurrentHold(instant, not powered)
    end

    ClientState.CurrentDistrict = districtId
    ClientState.CurrentGrid = gridId
    ClientState.CurrentFeeder = state.sourceFeederId
    ClientState.ActiveProfiles[districtId] = profileName
    ClientState.CurrentVisualProfile = profileName -- Phase 28 resolved profile

    if not powered then
        if heldByDistrict ~= districtId then
            acquireHold(districtId, profile, instant)
        end
    elseif heldByDistrict == districtId then
        releaseCurrentHold(instant)
    else
        -- No ownership means this may be a cancelled debug preview or a
        -- stale sequence that was interrupted during teleport. The new
        -- powered snapshot is authoritative, so remove the native effect
        -- even though there is no owner to release.
        forceRemoveStrayNative(profile)
    end

    ClientState.AppliedNativeBlackout = NativeBlackout.IsApplied()
end)

-- Full teardown for resource stop (spec §61) — unconditional, ignores
-- whatever `heldByDistrict`/ownership bookkeeping currently says, so a
-- restart can never leave a player stuck in a visual blackout the server
-- no longer thinks is active. Cancels any in-flight sequence first.
function VisualManager.Reset()
    Transition.Cancel()
    heldByDistrict = nil
    heldByProfile = nil
    NativeBlackout.Reset()
    if VisualHybrid and VisualHybrid.Reset then pcall(VisualHybrid.Reset) end
    VisualOwnership.Reset()
    ClientState.ActiveProfiles = {}
    ClientState.CurrentVisualProfile = nil
end

function VisualManager.GetActiveProfile(gridId)
    return ClientState.ActiveProfiles[gridId]
end
