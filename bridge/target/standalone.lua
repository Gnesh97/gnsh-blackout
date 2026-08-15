-- Standalone proximity target. Requires no external resource.

if not IsDuplicityVersion() then
    TargetAdapters = TargetAdapters or {}
    TargetAdapters.standalone = {}
    local A = TargetAdapters.standalone
    local activeInteractables = {}

    local function drawPrompt(spec)
        local coords = spec.coords
        local interaction = Config.Interaction or {}
        local height = spec.promptHeight or interaction.standalonePromptHeight or 0.85
        local scale = spec.promptScale or interaction.standalonePromptScale or 0.32
        local onScreen, screenX, screenY = World3dToScreen2d(coords.x, coords.y, coords.z + height)
        if not onScreen then return end

        SetTextScale(0.0, scale)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 235)
        SetTextCentre(true)
        SetTextOutline()
        BeginTextCommandDisplayText('STRING')
        AddTextComponentSubstringPlayerName(('~y~[E]~s~ %s'):format(spec.prompt or 'Etkileşime geç'))
        EndTextCommandDisplayText(screenX, screenY)
    end

    CreateThread(function()
        while true do
            local sleep = 1000
            local ped = PlayerPedId()
            if DoesEntityExist(ped) and not IsEntityDead(ped) then
                local pCoords = GetEntityCoords(ped)
                local nearest
                local nearestDistance = math.huge
                for _, spec in pairs(activeInteractables) do
                    local dist = #(pCoords - spec.coords)
                    local interaction = Config.Interaction or {}
                    local promptDistance = spec.promptDistance
                        or interaction.standalonePromptDistance
                        or 2.5
                    if dist <= promptDistance and dist < nearestDistance then
                        nearest = spec
                        nearestDistance = dist
                    end
                end

                if nearest then
                    sleep = 0
                    drawPrompt(nearest)
                    if IsControlJustReleased(0, 38) then Bridge.OpenMenu(nearest) end
                end
            end
            Wait(sleep)
        end
    end)

    function A.RegisterInteractable(spec)
        activeInteractables[spec.id] = spec
        return true
    end

    function A.RemoveInteractable(id)
        activeInteractables[id] = nil
        return true
    end
end
