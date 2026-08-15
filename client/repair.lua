-- Client repair UI. Progress implementation comes from Bridge.Progress;
-- server session/revision/distance checks remain authoritative.

Repair = {}

local repairStageLabels = {
    DIAGNOSE = 'Teşhis',
    ISOLATE_POWER = 'Gücü izole et',
    OPEN_PANEL = 'Paneli aç',
    REPLACE_COMPONENTS = 'Bileşenleri değiştir',
    REWIRE = 'Yeniden kablola',
    INSTALL_FUSE = 'Sigortayı tak',
    SYSTEM_TEST = 'Sistem testi',
    RECONNECT_POWER = 'Gücü yeniden bağla',
}

local function localizeRepairStage(stageName)
    return repairStageLabels[stageName] or tostring(stageName or 'İşlem')
end

function Repair.CancelProgress()
    if Bridge and type(Bridge.CancelProgress) == 'function' then
        pcall(Bridge.CancelProgress)
    end
end

local function runRepairProgress(label, durationMs)
    if Bridge and type(Bridge.Progress) == 'function' then
        return Bridge.Progress({
            duration = durationMs,
            label = label,
            variant = 'repair',
            stage = label,
            stageIndex = tonumber(label:match('%((%d+)/')),
            totalStages = tonumber(label:match('/(%d+)%)')),
            useWhileDead = false,
            canCancel = false,
            disable = { move = true, car = true, combat = true },
        })
    end
    Wait(durationMs)
    return true
end

RegisterNetEvent('infra:startRepairStage', function(sessionId, transformerId, stageName, stageIndex, totalStages)
    local durationMs = ((Config.Repair and Config.Repair.stageDurationSec) or 3) * 1000
    local label = ('Tamir: %s (%d/%d)'):format(localizeRepairStage(stageName), stageIndex, totalStages)
    local completed = runRepairProgress(label, durationMs)
    if completed then
        if Metrics then Metrics.Inc('client.networkEvent.server') end
        TriggerServerEvent('infra:submitRepairStage', sessionId)
    else
        -- A closed/reloaded UI or a local progress failure must release the
        -- server-owned repair session; otherwise the transformer remains
        -- locked until the session TTL expires.
        TriggerServerEvent('infra:cancelRepairStage', sessionId)
    end
end)
