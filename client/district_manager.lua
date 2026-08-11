--[[
    client/district_manager.lua

    Polls the player's GTA district (spec §5) with movement-aware gating,
    debounce/hysteresis (spec §29) to avoid flicker at district borders,
    and force-resolve on spawn/teleport (spec §29, §32).

    On a committed district change, fires the LOCAL client event
    'infra:districtChanged' with (newDistrict, newGridId, oldDistrict,
    oldGridId) — client/visual/manager.lua is the primary listener.
]]

DistrictManager = {}

-- district code -> gridId, built once from the static shared/grids.lua
-- topology. Mirrors GridManager's server-side index (Phase 4) but kept
-- local here since the client only ever needs this one direction.
local districtToGrid = {}
for gridId, grid in pairs(Grids) do
    for _, code in ipairs(grid.districts) do
        districtToGrid[code] = gridId
    end
end

local running = false

local function resolveGridForDistrict(district)
    if not district or district == Districts.UNKNOWN_CODE then return nil end
    return districtToGrid[district]
end

-- Applies a newly committed district/grid pair to ClientState and fires
-- the change event. Shared by both the debounced poll path and the
-- force-resolve path so there's exactly one place that "district changed"
-- actually happens.
local function commitDistrict(newDistrict, newGridId)
    local oldDistrict, oldGridId = ClientState.CurrentDistrict, ClientState.CurrentGrid
    if newDistrict == oldDistrict and newGridId == oldGridId then return end

    ClientState.CurrentDistrict = newDistrict
    ClientState.CurrentGrid = newGridId
    ClientState._districtCommitCount = ClientState._districtCommitCount + 1
    ClientState._pendingDistrict = nil
    ClientState._pendingSince = 0

    TriggerEvent('infra:districtChanged', newDistrict, newGridId, oldDistrict, oldGridId)
end

-- Runs the actual resolution (custom zone first, then native district)
-- and returns (district, gridId) — custom zones override the district's
-- own grid mapping, per spec §9 resolver priority.
local function resolveNow(coords)
    local customGrid, district = ClientZone.ResolvePosition(coords)
    if customGrid then
        return district, customGrid
    end

    if not district then
        district = ClientZone.ResolveDistrict(coords)
    end

    return district, resolveGridForDistrict(district)
end

-- Bypasses debounce entirely — used for spawn/teleport/resource-start
-- where waiting out the hysteresis window would be visibly wrong (spec
-- §32: late join/reconnect must reflect the correct state immediately).
function DistrictManager.ForceResolve()
    local coords = GetEntityCoords(PlayerPedId())
    ClientState._lastPollCoords = coords
    local district, gridId = resolveNow(coords)
    commitDistrict(district, gridId)
end

function DistrictManager.Start()
    if running then return end
    running = true

    DistrictManager.ForceResolve()

    CreateThread(function()
        while running do
            Wait(Config.District.pollInterval)

            local ped = PlayerPedId()
            if ped and ped ~= 0 then
                local coords = GetEntityCoords(ped)
                local last = ClientState._lastPollCoords

                local moved = last and Utils.Distance3D(coords, last) or math.huge

                if moved >= Config.District.teleportThreshold then
                    -- Large single-tick jump: teleport, not driving. Skip
                    -- debounce entirely (spec §29 force-resolve case).
                    ClientState._lastPollCoords = coords
                    local district, gridId = resolveNow(coords)
                    commitDistrict(district, gridId)
                elseif moved >= Config.District.moveThreshold then
                    ClientState._lastPollCoords = coords
                    local district, gridId = resolveNow(coords)

                    if district == ClientState.CurrentDistrict then
                        -- No change to debounce.
                        ClientState._pendingDistrict = nil
                        ClientState._pendingSince = 0
                    elseif district == ClientState._pendingDistrict then
                        -- Same candidate as last tick — check hysteresis window.
                        if (GetGameTimer() - ClientState._pendingSince) >= Config.District.stableTime then
                            commitDistrict(district, gridId)
                        end
                    else
                        -- New candidate — start the hysteresis clock.
                        ClientState._pendingDistrict = district
                        ClientState._pendingSince = GetGameTimer()
                    end
                end
                -- moved < moveThreshold: skip resolution entirely (spec §59
                -- performance principle — don't call GetNameOfZone every poll).
            end
        end
    end)
end

function DistrictManager.Stop()
    running = false
end
