--[[
    client/sabotage.lua

    Client Sabotage Interactions & Minigame Integration (spec §33, §34, Phase 12).

    Registers target / interaction points on configured transformers,
    handles client-side sabotage animation and minigames, and triggers
    explosion PTFX upon successful sabotage.
]]

Sabotage = {}

local function playPlantAnimation(ped)
    local animDict = 'anim@heists@ornate_bank@thermal_charge'
    local animName = 'thermal_charge'

    RequestAnimDict(animDict)
    local timeout = 500
    while not HasAnimDictLoaded(animDict) and timeout > 0 do
        Wait(10)
        timeout = timeout - 10
    end

    if HasAnimDictLoaded(animDict) then
        TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, -1, 49, 0, false, false, false)
    end
end

local function stopPlantAnimation(ped)
    ClearPedTasks(ped)
end

local function runSabotageMinigame(sabotageType, callback)
    local success = false

    -- 1. Try ox_lib skillCheck if available. `@ox_lib/init.lua` is
    -- imported in fxmanifest.lua so the `lib` global genuinely exists
    -- when ox_lib is running — GetResourceState() is the correct
    -- liveness check here (referencing `exports['ox_lib']` alone is
    -- always truthy, it's just a proxy table, and doesn't prove the
    -- resource actually started).
    if GetResourceState('ox_lib') == 'started' and lib and lib.skillCheck then
        -- TEST TUNING: 1 step, 'easy' only — shrink back to a real
        -- multi-step difficulty (see git history / CHANGELOG) once live
        -- testing moves past the sabotage flow itself.
        local checkDifficulty = { 'easy' }
        if sabotageType == 'c4' then
            checkDifficulty = { 'easy', 'medium' }
        end
        success = lib.skillCheck(checkDifficulty, { 'e', 'r' })
    -- 2. Try qb-lock / qb minigames if available
    elseif GetResourceState('qb-lock') == 'started' then
        local p = promise.new()
        exports['qb-lock']:StartLockPick(function(res)
            p:resolve(res)
        end, 4, 3)
        success = Citizen.Await(p)
    -- 3. Fallback: genuine timed reaction check, NOT an auto-win. The
    -- prompt appears after a random delay so the window can't be
    -- pre-timed by script; the player must press E within a short
    -- window or the attempt fails (spec §36 — result must not be
    -- trivially guaranteed).
    else
        local delay = math.random(1500, 3500)
        Wait(delay)

        local windowMs = 800
        local start = GetGameTimer()
        local pressed = false

        while (GetGameTimer() - start) < windowMs do
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName('~r~ŞİMDİ [E] TUŞUNA BAS!~s~')
            EndTextCommandDisplayHelp(0, false, true, -1)

            if IsControlJustPressed(0, 38) then -- INPUT_PICKUP (E)
                pressed = true
                break
            end
            Wait(0)
        end

        success = pressed
    end

    callback(success)
end

RegisterNetEvent('infra:startSabotageMinigame', function(sessionId, targetId, sabotageType, itemConfig)
    local ped = PlayerPedId()

    playPlantAnimation(ped)

    -- Wait min duration (3s) while playing animation & running minigame
    local minWaitPromise = promise.new()
    CreateThread(function()
        Wait((Config.Sabotage and Config.Sabotage.minCompletionTime * 1000) or 3500)
        minWaitPromise:resolve(true)
    end)

    runSabotageMinigame(sabotageType, function(minigameSuccess)
        -- Ensure minimum duration has elapsed so server session validation passes
        Citizen.Await(minWaitPromise)
        stopPlantAnimation(ped)

        if Metrics then Metrics.Inc('client.networkEvent.server') end
        TriggerServerEvent('infra:submitSabotageResult', sessionId, minigameSuccess)
    end)
end)

RegisterNetEvent('infra:playExplosion', function(coords)
    if not coords then return end

    -- Play GTA native explosion
    AddExplosion(coords.x, coords.y, coords.z, 2, 8.0, true, false, 1.2)

    -- Play spark PTFX
    RequestNamedPtfxAsset('core')
    local timeout = 500
    while not HasNamedPtfxAssetLoaded('core') and timeout > 0 do
        Wait(10)
        timeout = timeout - 10
    end

    if HasNamedPtfxAssetLoaded('core') then
        if Metrics then Metrics.Inc('client.ptfx.started') end
        UseParticleFxAssetNextCall('core')
        local ptfx = StartParticleFxLoopedAtCoord(
            'ent_dst_elec_crackle',
            coords.x, coords.y, coords.z + 1.0,
            0.0, 0.0, 0.0,
            1.5, false, false, false, false
        )

        SetTimeout(6000, function()
            StopParticleFxLooped(ptfx, 0)
        end)
    end
end)

-- Register interactables on startup for all known transformers.
--
-- NOTE (Phase 13): this is also where the "Trafoyu Tamir Et" option gets
-- added, not client/repair.lua — menuv shows one menu per interactable
-- id, so every option for a given transformer must live in the SAME
-- options array passed to ONE Bridge.RegisterInteractable() call.
-- Registering a second interactable with the same id from a different
-- file would overwrite this one's options instead of merging with them
-- (see bridge/target/standalone.lua's activeInteractables[spec.id] = spec
-- and textui.lua's equivalent — both are a full replace, not a merge).
local function initSabotageTargets()
    for trId, point in pairs(InfrastructureWorld or {}) do
        if point.type ~= 'transformer' or not point.enabled then
            goto continue
        end

        local trConfig = Transformers[trId]
        if not trConfig then
            goto continue
        end

        local interactId = 'infra:sabotage:' .. trId

        local options = {
            {
                icon = 'fa-solid fa-dumpster-fire',
                label = 'Termit İle Sabotaj Et',
                action = function()
                    TriggerServerEvent('infra:requestSabotage', trId, 'thermite')
                end,
            },
            {
                icon = 'fa-solid fa-bomb',
                label = 'C4 İle Patlat',
                action = function()
                    TriggerServerEvent('infra:requestSabotage', trId, 'c4')
                end,
            },
        }

        if Config.Repair and Config.Repair.enabled then
            options[#options + 1] = {
                icon = 'fa-solid fa-screwdriver-wrench',
                label = 'Trafoyu Tamir Et',
                action = function()
                    TriggerServerEvent('infra:requestRepair', trId)
                end,
            }
        end

        Bridge.RegisterInteractable({
            id = interactId,
            coords = point.coords,
            heading = point.heading or 0.0,
            length = 4.0,
            width = 4.0,
            label = trConfig.label or 'Trafo Sabotajı',
            distance = point.interactionRadius or 6.0,
            options = options,
        })

        ::continue::
    end
end

-- Teleport & Debug helper commands for in-game testing
RegisterCommand('tptrafo', function()
    local ped = PlayerPedId()
    local targetEntity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
    local point = InfrastructureWorld and InfrastructureWorld.sandy_tr_01
    local coords = point and point.coords or vector3(1961.0, 3745.0, 32.5)

    SetEntityCoords(targetEntity, coords.x, coords.y, coords.z, false, false, false, false)
    print('^2[gnsh-blackout] Teleported to Sandy Shores Transformer (1961.0, 3745.0, 32.5)^7')

    TriggerEvent('chat:addMessage', {
        color = { 0, 255, 128 },
        args = { '[gnsh-blackout]', 'Sandy Shores trafosuna (1961.0, 3745.0, 32.5) ışınlandınız!' }
    })
end, false)

-- Named /infracoords (not /infratest) — README.md documents /infratest as
-- a future in-game unit-test runner entry point (Phase 9's pure-Lua specs
-- loaded server-side); this is a plain coordinate/distance debug print
-- and must not squat that name.
RegisterCommand('infracoords', function()
    local ped = PlayerPedId()
    local pCoords = GetEntityCoords(ped)
    local point = InfrastructureWorld and InfrastructureWorld.sandy_tr_01
    local trCoords = point and point.coords or vector3(1961.0, 3745.0, 32.5)
    local dist = #(pCoords - trCoords)

    TriggerEvent('chat:addMessage', {
        color = { 255, 200, 0 },
        args = { '[gnsh-blackout]', ('Konumunuz: %.1f, %.1f, %.1f | Trafo Mesafesi: %.1fm'):format(pCoords.x, pCoords.y, pCoords.z, dist) }
    })
    print(('^2[gnsh-blackout] Pos=%.1f, %.1f, %.1f | Dist=%.1fm^7'):format(pCoords.x, pCoords.y, pCoords.z, dist))
end, false)

-- Phase 16.5: targetId is now REQUIRED (spec §30.2 "implicit nearest-target
-- gibi riskli davranışlardan kaçınılmalıdır") — used to silently default to
-- 'sandy_tr_01' when called with no args, which made no sense once more
-- than one transformer exists (Phase 18+).
RegisterCommand('sabotage', function(_, args)
    local targetId = args[1]
    if not targetId then
        print('^1[gnsh-blackout] usage: /sabotage <transformerId> [thermite|c4]^7')
        return
    end
    local sabType = args[2] or 'thermite'
    TriggerServerEvent('infra:requestSabotage', targetId, sabType)
end, false)

CreateThread(function()
    Wait(1000) -- Allow Bridge assembly to complete
    initSabotageTargets()
end)
