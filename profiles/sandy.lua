--[[
    profiles/sandy.lua

    Sandy MVP visual profile (spec §25). NATIVE_CLIENT_GATE only — no
    custom map work.

    blackoutSequence/recoverySequence (Phase 15, spec §30/§31): read by
    client/visual/transition.lua. `native_blackout.lua`'s adapter is a
    single blunt ON/OFF toggle (SetArtificialLightsState), not real
    per-light control, so a literal port of spec §30's example table
    (explosion/arc/flicker/lights-return/second-flicker/shutdown/native-
    blackout/stable) becomes a series of apply/remove toggles simulating
    that flicker — the closest approximation this adapter can produce.
    `ptfx`/`sound` steps stay no-ops (Phase 17 hybrid visual territory,
    same as the old `effects` block below).
    Timeline (seconds from sabotage/failure landing):
        0.00  (implicit) — sequence starts
        0.15  electrical arc            -> ptfx (no-op)
        0.35  first flicker             -> apply (lights blip off)
        0.55  lights return             -> remove
        0.75  second flicker            -> apply
        1.00  major shutdown            -> remove (brief return before final)
        1.30  native blackout           -> apply
        1.60  stable blackout           -> (Transition's own final snap, always 'apply')
    Recovery timeline (spec §31, seconds from repair completing):
        0.30  transformer hum           -> sound (no-op)
        0.60  electrical flicker        -> remove (lights blip back on)
        0.90  flicker settles           -> apply
        1.20  native blackout OFF       -> remove
        1.50  stable ONLINE             -> (Transition's own final snap, always 'remove')

    Loaded as a shared_script (both sides get a copy) so
    shared/validators.lua can confirm every grid's `visual.profile`
    actually resolved to something, and the client can read the same
    definition without a round trip.
]]

VisualProfiles = VisualProfiles or {}

VisualProfiles.sandy = {
    mode = Constants.VisualMode.NATIVE_CLIENT_GATE,

    districts = { 'SANDY' },

    nativeBlackout = {
        enabled = true,
        affectVehicles = false,
    },

    blackoutSequence = {
        { at = 0.15, action = 'ptfx' },
        { at = 0.35, action = 'apply' },
        { at = 0.55, action = 'remove' },
        { at = 0.75, action = 'apply' },
        { at = 1.00, action = 'remove' },
        { at = 1.30, action = 'apply' },
    },

    recoverySequence = {
        { at = 0.30, action = 'sound' },
        { at = 0.60, action = 'remove' },
        { at = 0.90, action = 'apply' },
        { at = 1.20, action = 'remove' },
    },

    -- Reserved for Phase 17 (hybrid visual expansion — dark motel signs,
    -- billboards, model swaps). Not read by anything before that phase;
    -- the 'ptfx'/'sound' sequence steps above are the Phase 15 hook
    -- point this will eventually attach to.
    effects = {
        transformerSparks = true,
        transformerSmoke = true,
        transformerSound = true,
    },
}
