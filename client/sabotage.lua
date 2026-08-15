-- Client sabotage interactions. UI/minigame implementations are selected
-- through Bridge; target registration keeps the existing public behavior.

Sabotage = {}

local function localizeTransformerLabel(label)
    local value = tostring(label or 'Trafo operasyonu')
    local replacements = {
        { 'Power Grid', 'Elektrik Şebekesi' },
        { 'Substation', 'Trafo Merkezi' },
        { 'Transformer', 'Trafo' },
        { 'Feeder', 'Besleyici' },
        { 'Central', 'Merkez' },
        { 'South', 'Güney' },
        { 'Desert', 'Çölü' },
    }

    for _, replacement in ipairs(replacements) do
        value = value:gsub(replacement[1], replacement[2])
    end
    return value
end

local function playPlantAnimation(ped)
    local animDict, animName = 'anim@heists@ornate_bank@thermal_charge', 'thermal_charge'
    RequestAnimDict(animDict)
    local timeout = 500
    while not HasAnimDictLoaded(animDict) and timeout > 0 do Wait(10); timeout = timeout - 10 end
    if HasAnimDictLoaded(animDict) then TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, -1, 49, 0, false, false, false) end
end

local function runSabotageMinigame(sabotageType, callback)
    local difficulty = sabotageType == 'c4' and { 'easy', 'medium' } or { 'easy' }
    if Bridge and type(Bridge.SkillCheck) == 'function' then
        callback(Bridge.SkillCheck(difficulty, { 'e', 'r' }, {
            variant = 'sabotage',
            title = sabotageType == 'c4' and 'Patlayıcı doğrulaması' or 'Termit doğrulaması',
        }))
        return
    end

    local delay = math.random(1500, 3500)
    Wait(delay)
    local start, pressed = GetGameTimer(), false
    while GetGameTimer() - start < 800 do
        BeginTextCommandDisplayHelp('STRING')
        AddTextComponentSubstringPlayerName('~r~ŞİMDİ [E] TUŞUNA BAS!~s~')
        EndTextCommandDisplayHelp(0, false, true, -1)
        if IsControlJustPressed(0, 38) then pressed = true; break end
        Wait(0)
    end
    callback(pressed)
end

RegisterNetEvent('infra:startSabotageMinigame', function(sessionId, targetId, sabotageType, _itemConfig)
    local ped = PlayerPedId()
    playPlantAnimation(ped)
    local minWaitPromise = promise.new()
    CreateThread(function()
        Wait((Config.Sabotage and Config.Sabotage.minCompletionTime * 1000) or 3500)
        minWaitPromise:resolve(true)
    end)

    runSabotageMinigame(sabotageType, function(success)
        Citizen.Await(minWaitPromise)
        ClearPedTasks(ped)
        if Metrics then Metrics.Inc('client.networkEvent.server') end
        TriggerServerEvent('infra:submitSabotageResult', sessionId, success == true)
    end)
end)

RegisterNetEvent('infra:playExplosion', function(coords)
    if not coords then return end
    AddExplosion(coords.x, coords.y, coords.z, 2, 8.0, true, false, 1.2)
    RequestNamedPtfxAsset('core')
    local timeout = 500
    while not HasNamedPtfxAssetLoaded('core') and timeout > 0 do Wait(10); timeout = timeout - 10 end
    if HasNamedPtfxAssetLoaded('core') then
        if Metrics then Metrics.Inc('client.ptfx.started') end
        UseParticleFxAssetNextCall('core')
        local ptfx = StartParticleFxLoopedAtCoord('ent_dst_elec_crackle', coords.x, coords.y, coords.z + 1.0, 0.0, 0.0, 0.0, 1.5, false, false, false, false)
        SetTimeout(6000, function() StopParticleFxLooped(ptfx, 0) end)
    end
end)

local function initSabotageTargets()
    for trId, point in pairs(InfrastructureWorld or {}) do
        if point.type ~= 'transformer' or not point.enabled then goto continue end
        local trConfig = Transformers[trId]
        if not trConfig then goto continue end

        local options = {
            {
                icon = 'fa-solid fa-dumpster-fire',
                label = 'Termit ile sabotaj',
                description = 'Trafoyu ağır hasara sürükler. Sessiz, kontrollü müdahale.',
                tone = 'warning',
                action = function() TriggerServerEvent('infra:requestSabotage', trId, 'thermite') end,
            },
            {
                icon = 'fa-solid fa-bomb',
                label = 'C4 ile patlat',
                description = 'Trafoyu anında devre dışı bırakır. Geri dönüş maliyeti yüksek.',
                tone = 'danger',
                action = function() TriggerServerEvent('infra:requestSabotage', trId, 'c4') end,
            },
        }
        if Config.Repair and Config.Repair.enabled then
            options[#options + 1] = {
                icon = 'fa-solid fa-screwdriver-wrench',
                label = 'Trafoyu tamir et',
                description = 'Hasar planını çalıştırır ve sistemi tekrar hatta alır.',
                tone = 'safe',
                action = function() TriggerServerEvent('infra:requestRepair', trId) end,
            }
        end
        Bridge.RegisterInteractable({
            id = 'infra:sabotage:' .. trId,
            coords = point.coords,
            heading = point.heading or 0.0,
            length = 4.0, width = 4.0,
            label = localizeTransformerLabel(trConfig.label),
            prompt = 'Trafoyu incele',
            promptDistance = (Config.Interaction and Config.Interaction.standalonePromptDistance) or 2.5,
            promptHeight = (Config.Interaction and Config.Interaction.standalonePromptHeight) or 0.85,
            variant = 'infrastructure',
            subtitle = 'Operasyon seçin',
            distance = point.interactionRadius or 6.0,
            options = options,
        })
        ::continue::
    end
end

RegisterCommand('tptrafo', function()
    local ped = PlayerPedId()
    local entity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
    local point = InfrastructureWorld and InfrastructureWorld.sandy_tr_01
    local coords = point and point.coords or vector3(1961.0, 3745.0, 32.5)
    SetEntityCoords(entity, coords.x, coords.y, coords.z, false, false, false, false)
    print('^2[gnsh-blackout] Teleported to Sandy Shores Transformer^7')
end, false)

RegisterCommand('infracoords', function()
    local ped = PlayerPedId(); local pCoords = GetEntityCoords(ped)
    local point = InfrastructureWorld and InfrastructureWorld.sandy_tr_01
    local coords = point and point.coords or vector3(1961.0, 3745.0, 32.5)
    local dist = #(pCoords - coords)
    TriggerEvent('chat:addMessage', { color = { 255, 200, 0 }, args = { '[gnsh-blackout]', ('Konumunuz: %.1f, %.1f, %.1f | Trafo Mesafesi: %.1fm'):format(pCoords.x, pCoords.y, pCoords.z, dist) } })
end, false)

RegisterCommand('sabotage', function(_, args)
    if not args[1] then print('^1[gnsh-blackout] usage: /sabotage <transformerId> [thermite|c4]^7'); return end
    TriggerServerEvent('infra:requestSabotage', args[1], args[2] or 'thermite')
end, false)

CreateThread(function() Wait(1000); initSabotageTargets() end)
