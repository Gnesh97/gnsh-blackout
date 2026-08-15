-- Last-resort dependency-free native fallback for progress and skillcheck.
-- The bridge's internal routes try the resource-owned NUI first. No NUI frame
-- is created here, so this renderer is only used when that layer is absent.

if IsDuplicityVersion() then return end

InternalUI = InternalUI or {}

local progressGeneration = 0
local progressActive = false

local function helpText(message)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function disableProgressControls(disable)
    if type(disable) ~= 'table' then return end
    if disable.move then
        DisableControlAction(0, 30, true)
        DisableControlAction(0, 31, true)
        DisableControlAction(0, 21, true)
    end
    if disable.car then
        DisableControlAction(0, 59, true)
        DisableControlAction(0, 60, true)
        DisableControlAction(0, 75, true)
    end
    if disable.combat then
        DisablePlayerFiring(PlayerId(), true)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
    end
end

function InternalUI.StartProgress(data)
    progressGeneration = progressGeneration + 1
    local generation = progressGeneration
    local duration = math.max(0, tonumber(data and data.duration) or 0)
    local label = tostring(data and data.label or 'İşlem')
    local canCancel = data and data.canCancel ~= false
    local startedAt = GetGameTimer()
    progressActive = true

    while progressGeneration == generation and GetGameTimer() - startedAt < duration do
        local elapsed = GetGameTimer() - startedAt
        local percent = duration > 0 and math.min(100, math.floor((elapsed / duration) * 100)) or 100
        local cancelText = canCancel and '~n~~r~[BACKSPACE] Iptal~s~' or ''
        helpText(('~y~%s~s~  %d%%%s'):format(label, percent, cancelText))
        disableProgressControls(data and data.disable)
        if canCancel and IsControlJustReleased(0, 177) then
            progressGeneration = progressGeneration + 1
            progressActive = false
            return false
        end
        Wait(0)
    end

    local completed = progressGeneration == generation
    if completed then progressActive = false end
    return completed
end

function InternalUI.CancelProgress()
    if not progressActive then return false end
    progressGeneration = progressGeneration + 1
    progressActive = false
    return true
end

local function skillWindow(level)
    if level == 'hard' then return 650 end
    if level == 'medium' then return 850 end
    return 1200
end

local function drawSkillPrompt(message, remainingMs)
    local remaining = math.max(0, math.ceil((tonumber(remainingMs) or 0) / 1000))
    DrawRect(0.5, 0.825, 0.42, 0.105, 0, 0, 0, 185)
    SetTextFont(4)
    SetTextScale(0.0, 0.42)
    SetTextColour(255, 255, 255, 255)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(('~y~SKILL CHECK~s~~n~%s~n~~c~Kalan: %ds'):format(message, remaining))
    EndTextCommandDisplayText(0.5, 0.785)
end

local function suppressSkillControls()
    -- E is also the standalone target interaction key. Disable it (and the
    -- alternate R input) while the skillcheck owns the keyboard so the target
    -- loop cannot reopen the sabotage menu between stages.
    DisableControlAction(0, 38, true)
    DisableControlAction(0, 45, true)
end

local function runSkillStage(level, inputs)
    local choices = type(inputs) == 'table' and inputs or { 'e' }
    if #choices == 0 then choices = { 'e' } end
    local key = tostring(choices[math.random(1, #choices)] or 'e'):lower()
    local controls = { e = 38, r = 45 }
    local expected = controls[key] or 38

    local preparationMs = math.random(700, 1300)
    local preparationStartedAt = GetGameTimer()
    while GetGameTimer() - preparationStartedAt < preparationMs do
        local elapsed = GetGameTimer() - preparationStartedAt
        suppressSkillControls()
        drawSkillPrompt('HAZIR OL...', preparationMs - elapsed)
        Wait(0)
    end

    local startedAt = GetGameTimer()
    local duration = skillWindow(level)
    while GetGameTimer() - startedAt < duration do
        local elapsed = GetGameTimer() - startedAt
        suppressSkillControls()
        drawSkillPrompt(('SIMDI [%s] TUSUNA BAS!'):format(key:upper()), duration - elapsed)
        helpText(('~r~SIMDI [%s] TUSUNA BAS!~s~'):format(key:upper()))
        if IsDisabledControlJustPressed(0, expected) then return true end
        for candidate, control in pairs(controls) do
            if candidate ~= key and IsDisabledControlJustPressed(0, control) then return false end
        end
        Wait(0)
    end
    return false
end

function InternalUI.SkillCheck(difficulty, inputs)
    local stages = type(difficulty) == 'table' and difficulty or { difficulty or 'easy' }
    for _, level in ipairs(stages) do
        if not runSkillStage(level, inputs) then return false end
    end
    return true
end
