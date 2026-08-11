--[[
    profiles/ls_central.lua

    Minimal visual profile for the `ls_central` grid (Phase 18 — second
    region, added so "multiple grids running simultaneously" (spec §18.7)
    is a real thing to test, not just a claim). Same NATIVE_CLIENT_GATE
    mode as profiles/sandy.lua, no blackoutSequence/recoverySequence —
    client/visual/transition.lua already falls back to a single-step
    instant apply/remove when a profile doesn't define one (see that
    file's header comment), so this is a deliberately bare-bones profile
    until a real Los Santos visual pass happens (spec §28, Phase 28 —
    explicitly not this phase's scope).
]]

VisualProfiles = VisualProfiles or {}

VisualProfiles.ls_central = {
    mode = Constants.VisualMode.NATIVE_CLIENT_GATE,
    districts = { 'DOWNT', 'PBOX', 'SKID' },
    nativeBlackout = {
        enabled = true,
        affectVehicles = false,
    },
}
