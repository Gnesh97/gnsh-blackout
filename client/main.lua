--[[
    client/main.lua

    Client orchestrator: StateBag listener (spec §19-20), lifecycle
    (spawn/late-join/resource-stop, spec §32/§61), and client-side exports
    mirroring the server API (spec §48) so UI-only code never has to
    round-trip to the server just to ask "is it dark here right now".

    IMPORTANT — why district transitions ALSO need an explicit GlobalState
    read, not just the StateBag change handler:
    Walking from a powered district into a blacked-out one changes
    nothing server-side — no StateBag write happens, because the OTHER
    district's state didn't change. The change handler alone would never
    fire. So every district transition (see the 'infra:districtChanged'
    listener below) explicitly re-reads GlobalState for the newly entered
    district, exactly like a late-join client would (spec §32).

    Phase 18 — gates on DISTRICT state, not grid state: before the feeder
    layer, every district under a grid shared that grid's exact power
    state, so reading the grid's GlobalState key was equivalent. Now a
    grid can have two feeders in different states (spec §18.7's whole
    point), so two districts under the SAME grid can legitimately differ —
    gating on grid state here would make that backend distinction
    invisible in-game. `gridId` is still read/carried in the event payload
    purely so client/visual/manager.lua can resolve which VISUAL PROFILE
    to use (spec §26/§28: profiles are still owned by the grid, not yet
    per-district — that's Phase 28 territory) — it no longer decides
    whether the lights are on.
]]

-- Re-applies whatever is CURRENTLY published for `districtId` to
-- ClientState, and fires 'infra:powerStateChanged' so client/visual/
-- manager.lua (Phase 8) can react. Used at startup (late join), and every
-- time the player's current district changes (see the districtChanged
-- handler below). Both of those call sites are snapshot reads, not a live
-- change someone just caused — `instant = true` (spec §32) tells
-- VisualManager to snap straight to the correct state instead of playing
-- the Phase 15 explosion/flicker sequence for something that already
-- happened.
local function publishLinkStatus(powered)
    if type(SendNUIMessage) ~= 'function' then return end

    local stable = powered == true
    SendNUIMessage({
        action = 'linkStatus',
        powered = stable,
        unstable = not stable,
    })
end

local function applyDistrictState(districtId, gridId, instant)
    ClientState.CurrentDistrict = districtId
    ClientState.CurrentGrid = gridId
    ClientState.CurrentFeeder = nil

    if not districtId then
        -- No district at all (unmanaged territory) — treat as powered,
        -- per the same fail-open rule the server API uses.
        ClientState.CurrentPowerRevision = -1
        ClientState.CurrentPowered = true
        publishLinkStatus(true)
        TriggerEvent('infra:powerStateChanged', {
            gridId = gridId, districtId = nil, feederIds = {}, sourceFeederId = nil,
            powered = true, level = 1.0, status = Constants.GridStatus.ONLINE,
            revision = -1, instant = instant,
        })
        return
    end

    local state = GlobalState[Constants.StateKey.DISTRICT .. districtId]
    if not state then
        -- District exists in the registry but the server hasn't
        -- published anything for it yet (unassigned, or this client's
        -- resource started before the server's did). Fail open rather
        -- than assume blackout.
        ClientState.CurrentPowerRevision = -1
        ClientState.CurrentPowered = true
        publishLinkStatus(true)
        TriggerEvent('infra:powerStateChanged', {
            gridId = gridId, districtId = districtId, feederIds = {}, sourceFeederId = nil,
            powered = true, level = 1.0, status = Constants.GridStatus.ONLINE,
            revision = -1, instant = instant,
        })
        return
    end

    ClientState.CurrentPowerRevision = state.revision
    ClientState.CurrentPowered = state.powered
    ClientState.CurrentFeeder = state.sourceFeederId
    publishLinkStatus(state.powered)

    local payload = {}
    for k, v in pairs(state) do payload[k] = v end
    payload.gridId = gridId
    payload.districtId = districtId
    payload.instant = instant
    TriggerEvent('infra:powerStateChanged', payload)
end

AddEventHandler('infra:districtChanged', function(newDistrict, newGridId, oldDistrict, _oldGridId)
    if newDistrict ~= oldDistrict then
        applyDistrictState(newDistrict, newGridId, true) -- district transition (spec §29), not a live change — snap
    end
end)

-- Ignores stale revisions per spec §20 — an out-of-order or duplicate
-- StateBag update for a district we've already seen a newer revision for
-- is simply dropped. This IS a genuine live change (someone actually
-- flipped power on the player's CURRENT district) — instant = false, so
-- VisualManager plays the full Phase 15 transition sequence.
AddStateBagChangeHandler(nil, 'global', function(bagName, key, value)
    if bagName ~= 'global' then return end
    if not value then return end

    local districtId = ClientState.CurrentDistrict
    if not districtId then return end

    if key == Constants.StateKey.DISTRICT .. districtId then
        if value.revision <= ClientState.CurrentPowerRevision then return end
        ClientState.CurrentPowerRevision = value.revision
        ClientState.CurrentPowered = value.powered
        ClientState.CurrentFeeder = value.sourceFeederId
        publishLinkStatus(value.powered)

        local payload = {}
        for k, v in pairs(value) do payload[k] = v end
        payload.gridId = value.gridId or ClientState.CurrentGrid
        payload.districtId = districtId
        payload.instant = false
        TriggerEvent('infra:powerStateChanged', payload)
    end
end)

RegisterNetEvent('gnsh-blackout:client:resyncVisual', function()
    if Metrics then Metrics.Inc('client.visual.resync') end
    applyDistrictState(ClientState.CurrentDistrict, ClientState.CurrentGrid, true)
end)

RegisterNetEvent('gnsh-blackout:client:adminOpen', function(payload)
    if not AdminUI or type(AdminUI.Open) ~= 'function' then return end
    AdminUI.Open(payload)
end)

RegisterNetEvent('gnsh-blackout:client:adminData', function(payload)
    if not AdminUI or type(AdminUI.Update) ~= 'function' then return end
    AdminUI.Update(payload)
end)

local function start()
    if Metrics and Metrics.Start then Metrics.Start() end
    -- SetArtificialLightsState is client-global and its native state can
    -- outlive a resource reload even though NativeBlackout's Lua flag resets.
    -- Clear the stale visual before applying the authoritative snapshot below.
    if NativeBlackout and NativeBlackout.Reset then NativeBlackout.Reset() end
    DistrictManager.Start()
    applyDistrictState(ClientState.CurrentDistrict, ClientState.CurrentGrid, true) -- late-join / resource-(re)start snapshot read
end

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    start()
end)

if GetResourceState(GetCurrentResourceName()) == 'started' then
    -- Script got (re)loaded while the resource was already running (e.g.
    -- a `refresh` + live script swap) — onClientResourceStart won't fire
    -- again, so bootstrap immediately.
    CreateThread(start)
end

-- Also force a fresh resolve on player (re)spawn — covers first spawn
-- after connecting and death/respawn, where the ped coords can jump
-- without a "teleport-sized" single-tick movement delta being observed
-- by the poll loop (spec §29 force-resolve case).
AddEventHandler('playerSpawned', function()
    DistrictManager.ForceResolve()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if Repair and Repair.CancelProgress then Repair.CancelProgress() end
    DistrictManager.Stop()
    if Metrics and Metrics.Stop then Metrics.Stop() end
    if VisualManager then VisualManager.Reset() end -- Phase 8; guarded for load-order safety
    ClientState.Reset()
end)

-- ── Client-side public exports (spec §48) ───────────────────────────────
-- Mirrors the server API but reads directly from the already-replicated
-- GlobalState — no server round-trip needed for a client-side caller
-- (e.g. a HUD element asking "is my current building powered").

exports('IsGridPowered', function(gridId)
    local state = GlobalState[Constants.StateKey.GRID .. gridId]
    return state ~= nil and state.powered or false
end)

exports('IsDistrictPowered', function(district)
    local state = GlobalState[Constants.StateKey.DISTRICT .. district]
    if state then return state.powered end
    return true
end)

exports('GetGridState', function(gridId)
    return GlobalState[Constants.StateKey.GRID .. gridId]
end)

exports('GetDistrictState', function(district)
    return GlobalState[Constants.StateKey.DISTRICT .. district]
end)
