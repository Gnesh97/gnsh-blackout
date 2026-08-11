--[[
    client/visual/native_blackout.lua

    The NATIVE_CLIENT_GATE visual adapter (spec §21, §22, §25). This is
    NOT a real district-scoped lighting native — SetArtificialLightsState
    affects the whole client's artificial lighting globally (spec §21).
    What makes this "district-based client gating" rather than a lie is
    that client/visual/manager.lua only calls Apply() while the LOCAL
    PLAYER is standing in an unpowered district, and Remove() the instant
    they leave it — so from that one client's point of view, lights outside
    their current district were never touched, because they were never in
    an unpowered district anywhere else at the same time. This must never
    be described as true per-district native lighting (spec §22 warning).

    Adapter contract (spec §28): Apply/Remove/IsApplied/ForceSync/Reset,
    all idempotent — calling Apply() three times in a row has the same
    effect as calling it once, same for Remove().

    Visual failure safety (spec §62): every native call is wrapped in
    pcall. A failure here is logged (VISUAL_FAILED) but can NEVER be
    allowed to affect ClientState.CurrentPowered — that's server-derived
    truth and this module has no path back to it.
]]

NativeBlackout = {}

local applied = false

local function safeCall(fnName, fn)
    local ok, err = pcall(fn)
    if not ok then
        print(('^1[gnsh-blackout] VISUAL_FAILED in NativeBlackout.%s: %s^7'):format(fnName, tostring(err)))
    end
    return ok
end

function NativeBlackout.Apply(affectVehicles)
    if Metrics then Metrics.Inc('client.visual.apply') end
    if applied then return true end -- idempotent

    local ok = safeCall('Apply', function()
        SetArtificialLightsState(true)
        if SetArtificialLightsStateAffectsVehicles then
            SetArtificialLightsStateAffectsVehicles(affectVehicles == true)
        end
    end)

    if ok then
        applied = true
        print('^5[gnsh-blackout]^7 VISUAL_APPLIED native_client_gate')
    end
    return ok
end

function NativeBlackout.Remove()
    if Metrics then Metrics.Inc('client.visual.remove') end
    if not applied then return true end -- idempotent

    local ok = safeCall('Remove', function()
        SetArtificialLightsState(false)
    end)

    if ok then
        applied = false
    end
    return ok
end

function NativeBlackout.IsApplied()
    return applied
end

-- Re-asserts the current applied/removed state against the natives
-- without flipping `applied` — used after things like a game reload or
-- suspected native desync, where the internal flag might say "applied"
-- but the actual game state drifted.
function NativeBlackout.ForceSync()
    safeCall('ForceSync', function()
        SetArtificialLightsState(applied)
    end)
end

-- Unconditional teardown regardless of the `applied` flag — used on
-- resource stop (spec §61) so a stale flag can never leave a player in
-- the dark after a restart.
function NativeBlackout.Reset()
    safeCall('Reset', function()
        SetArtificialLightsState(false)
    end)
    applied = false
end
