--[[
    client/repair.lua

    Client-side repair progress UI (spec §37, §38, Phase 13). The server
    (server/repair_manager.lua) owns every decision — this file only runs
    a progress bar for the duration the server told it and reports back
    "done" via the session id the server issued.

    The "Trafoyu Tamir Et" interactable OPTION itself is registered in
    client/sabotage.lua's initSabotageTargets(), not here — see that
    file's header note. menuv only shows one menu per interactable id, so
    every option for the same transformer (Termit/C4/Repair) must live in
    ONE options array passed to ONE Bridge.RegisterInteractable() call;
    splitting registration across files would mean the second call
    overwrites the first's options instead of joining them.

    `runRepairProgress()` is the only function that touches
    lib.progressBar — same isolation pattern as client/sabotage.lua's
    runSabotageMinigame(), for the same reason (user-flagged future NUI
    overhaul).
]]

Repair = {}

-- ox_lib owns the progress loop. If this resource is restarted while a
-- stage is active, cancel that loop before the script host tears down the
-- event handler that started it; otherwise ox_lib can report a stale
-- function-reference error during cleanup.
function Repair.CancelProgress()
    if GetResourceState('ox_lib') ~= 'started' or not lib then return end
    if type(lib.progressActive) ~= 'function' or type(lib.cancelProgress) ~= 'function' then return end

    local ok, active = pcall(lib.progressActive)
    if ok and active then
        pcall(lib.cancelProgress)
    end
end

local function runRepairProgress(label, durationMs)
    if GetResourceState('ox_lib') == 'started' and lib and lib.progressBar then
        lib.progressBar({
            duration = durationMs,
            label = label,
            useWhileDead = false,
            canCancel = false,
            disable = { move = true, car = true, combat = true },
        })
    else
        -- Fallback: no ox_lib progressBar available, just wait out the
        -- duration silently rather than blocking the repair entirely.
        Wait(durationMs)
    end
end

RegisterNetEvent('infra:startRepairStage', function(sessionId, transformerId, stageName, stageIndex, totalStages)
    local durationMs = ((Config.Repair and Config.Repair.stageDurationSec) or 3) * 1000
    local label = ('Tamir: %s (%d/%d)'):format(stageName, stageIndex, totalStages)

    runRepairProgress(label, durationMs)

    if Metrics then Metrics.Inc('client.networkEvent.server') end
    TriggerServerEvent('infra:submitRepairStage', sessionId)
end)
