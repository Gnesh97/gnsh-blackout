--[[
    client/visual/transition.lua

    Blackout/Recovery Transition Engine (spec §30, §31, Phase 15). A pure
    sequencer — it drives the EXISTING NativeBlackout.Apply/Remove adapter
    (client/visual/native_blackout.lua) along a config-driven timeline. No
    new visual natives, no new adapter: same Apply/Remove calls this
    project already had, just ordered in time instead of firing once.

    Timing is purely visual (matches the spec's own framing: "Server
    logical state daha önce OFF olmuş olabilir" — the server already
    knows the real power state, this module only decides how long the
    CLIENT takes to visually catch up).

    CANCELLATION: every running sequence carries a monotonic token,
    checked after every Wait(). A new power event mid-sequence bumps the
    token, so a stale sequence can never re-apply a state that's no
    longer true — this is what makes "sabotage a transformer while a
    recovery sequence from a PREVIOUS repair is still playing" safe.

    LATE-JOIN / RESTART MUST NOT REPLAY (spec §32): this module has no
    opinion on that — client/visual/manager.lua decides whether to call
    Transition.PlayBlackout/PlayRecovery (genuine live change) or
    Transition.ForceSync (startup/late-join/district-transition snapshot)
    based on the `instant` flag on the 'infra:powerStateChanged' payload.
]]

Transition = {}

local sequenceToken = 0

local function sortedCopy(sequence)
    local copy = {}
    for i, step in ipairs(sequence) do copy[i] = step end
    table.sort(copy, function(a, b) return a.at < b.at end)
    return copy
end

local function applyStep(action, affectVehicles)
    if action == 'apply' then
        NativeBlackout.Apply(affectVehicles)
    elseif action == 'remove' then
        NativeBlackout.Remove()
    end
    -- 'ptfx' / 'sound' steps are reserved for Phase 17's hybrid visual
    -- expansion (transformer sparks/smoke/sound, profiles/sandy.lua's
    -- `effects` block) — intentionally no-op today, same as before this
    -- phase existed.
end

local function runSequence(sequence, finalAction, affectVehicles, onComplete)
    sequenceToken = sequenceToken + 1
    local myToken = sequenceToken
    local steps = sortedCopy(sequence)

    CreateThread(function()
        local startTime = GetGameTimer()

        for _, step in ipairs(steps) do
            local elapsedSec = (GetGameTimer() - startTime) / 1000.0
            local remainingMs = math.floor((step.at - elapsedSec) * 1000)
            if remainingMs > 0 then
                Wait(remainingMs)
            end

            if sequenceToken ~= myToken then return end -- cancelled by a newer sequence
            applyStep(step.action, affectVehicles)
        end

        if sequenceToken ~= myToken then return end

        -- Snap to the guaranteed-correct final state regardless of what
        -- the last step happened to do — belt-and-suspenders against a
        -- misconfigured profile leaving the wrong native state applied.
        applyStep(finalAction, affectVehicles)

        if onComplete then onComplete() end
    end)
end

-- profile.blackoutSequence: array of { at = seconds, action = 'apply'|'remove'|'ptfx'|'sound' }.
-- Falls back to an instant single-step apply if the profile doesn't
-- define one (keeps old profiles working unchanged).
function Transition.PlayBlackout(profile, onComplete)
    local sequence = profile.blackoutSequence or { { at = 0, action = 'apply' } }
    local affectVehicles = profile.nativeBlackout and profile.nativeBlackout.affectVehicles
    runSequence(sequence, 'apply', affectVehicles, onComplete)
end

function Transition.PlayRecovery(profile, onComplete)
    local sequence = profile.recoverySequence or { { at = 0, action = 'remove' } }
    local affectVehicles = profile.nativeBlackout and profile.nativeBlackout.affectVehicles
    runSequence(sequence, 'remove', affectVehicles, onComplete)
end

-- Aborts whatever sequence is currently running (if any) without
-- touching the native state itself.
function Transition.Cancel()
    sequenceToken = sequenceToken + 1
end

-- Snaps directly to the correct final state — no sequence, no delay.
-- Used for startup/late-join/district-transition (spec §32: never replay
-- the explosion/flicker sequence for a state that was already true
-- before this client cared about it).
function Transition.ForceSync(shouldBeApplied, affectVehicles)
    Transition.Cancel()
    if shouldBeApplied then
        NativeBlackout.Apply(affectVehicles)
    else
        NativeBlackout.Remove()
    end
end
