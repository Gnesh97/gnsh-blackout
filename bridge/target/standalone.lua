--[[
    bridge/target/standalone.lua

    Standalone Proximity & 3D Text / HelpText / Menu Target Adapter (client-only).
    Requires ZERO external resources (works out-of-the-box on QBCore, ESX, or Standalone).

    MULTI-OPTION HANDLING: an interactable with more than one option
    (e.g. Sandy's transformer — Termit vs C4) opens a `menuv` menu on
    E-press via bridge/target/menu_helper.lua's MenuHelper.OpenOptions()
    (menuv confirmed installed under [standalone]/menuv) so every option
    is actually reachable, not just the first one. That shared helper is
    the ONLY code that knows about menuv — see menu_helper.lua's header
    for why it's kept out of this file.
]]

if not IsDuplicityVersion() then
    TargetAdapters = TargetAdapters or {}
    TargetAdapters.standalone = {}

    local A = TargetAdapters.standalone
    local activeInteractables = {}

    CreateThread(function()
        while true do
            local sleep = 1000
            local ped = PlayerPedId()
            if DoesEntityExist(ped) and not IsEntityDead(ped) then
                local pCoords = GetEntityCoords(ped)

                for id, spec in pairs(activeInteractables) do
                    local dist = #(pCoords - spec.coords)
                    local interactDist = spec.distance or 6.0

                    if dist <= interactDist then
                        sleep = 0

                        -- Draw visible orange ground marker at target position
                        DrawMarker(
                            1, -- Cylinder
                            spec.coords.x, spec.coords.y, spec.coords.z - 1.0,
                            0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0,
                            1.5, 1.5, 0.8,
                            255, 165, 0, 180,
                            false, true, 2, false, nil, nil, false
                        )

                        -- Display Help Text
                        local label = spec.label or (spec.options and spec.options[1] and spec.options[1].label) or 'Etkileşim'
                        BeginTextCommandDisplayHelp('STRING')
                        AddTextComponentSubstringPlayerName(('[E] %s'):format(label))
                        EndTextCommandDisplayHelp(0, false, true, -1)

                        if IsControlJustReleased(0, 38) then -- INPUT_PICKUP (E key)
                            MenuHelper.OpenOptions(spec)
                        end
                    end
                end
            end

            Wait(sleep)
        end
    end)

    function A.RegisterInteractable(spec)
        activeInteractables[spec.id] = spec
    end

    function A.RemoveInteractable(id)
        activeInteractables[id] = nil
    end

    print('^2[gnsh-blackout] bridge/target/standalone.lua loaded^7')
end
