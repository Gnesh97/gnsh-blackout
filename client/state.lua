--[[
    client/state.lua

    Client-side cache (spec §60). Single source of truth for "what does
    this client currently believe about its surroundings" — district_
    manager.lua and visual/manager.lua both read/write this instead of
    keeping their own copies, so debug output (/griddebug) and cleanup
    (§61) only need to touch one table.
]]

ClientState = {
    CurrentDistrict = nil,
    CurrentGrid = nil,
    CurrentFeeder = nil,        -- spec §19.2, Phase 19 — selected/effective source feeder for the current district
    CurrentVisualProfile = nil, -- spec §19.2 — mirrors ActiveProfiles[CurrentGrid] as a direct field
    CurrentPowerRevision = -1, -- -1 so the very first StateBag update (revision 0+) always applies
    CurrentPowered = true,

    AppliedNativeBlackout = false,

    ActiveProfiles = {},   -- [gridId] = profileName
    ActiveAssets = {},     -- reserved for Phase 15-17 hybrid visual layers
    ActiveModelSwaps = {},
    ActiveIPLs = {},
    ActiveInteriorSets = {},
    ActivePTFX = {},
    ActiveSounds = {},

    -- Debounce/hysteresis bookkeeping (spec §29) — see client/district_manager.lua
    _pendingDistrict = nil,
    _pendingSince = 0,
    _lastPollCoords = nil,
    _districtCommitCount = 0,
}

-- Reset everything to a safe, "nothing applied" baseline. Called on
-- resource stop (spec §61) so a restart never leaves a player stuck in a
-- visual blackout the server no longer thinks is active.
function ClientState.Reset()
    ClientState.CurrentDistrict = nil
    ClientState.CurrentGrid = nil
    ClientState.CurrentFeeder = nil
    ClientState.CurrentVisualProfile = nil
    ClientState.CurrentPowerRevision = -1
    ClientState.CurrentPowered = true
    ClientState.AppliedNativeBlackout = false
    ClientState.ActiveProfiles = {}
    ClientState.ActiveAssets = {}
    ClientState.ActiveModelSwaps = {}
    ClientState.ActiveIPLs = {}
    ClientState.ActiveInteriorSets = {}
    ClientState.ActivePTFX = {}
    ClientState.ActiveSounds = {}
    ClientState._pendingDistrict = nil
    ClientState._pendingSince = 0
    ClientState._lastPollCoords = nil
end
