-- Internal menu route. It forwards to the resource-owned NUI first; GTA help
-- text remains the last-resort fallback when the browser layer is unavailable.

if IsDuplicityVersion() then return end

MenuAdapters = MenuAdapters or {}
MenuAdapters.internal = {}
local A = MenuAdapters.internal
local menuGeneration = 0
local universalForwarding = false

local function tryUniversal(spec)
    if universalForwarding then return false, nil end
    local adapter = MenuAdapters.nui
    if type(adapter) ~= 'table' or type(adapter.OpenMenu) ~= 'function' then return false, nil end

    universalForwarding = true
    local ok, result = pcall(adapter.OpenMenu, spec)
    universalForwarding = false
    return true, ok and result or false
end

local function helpText(message)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

function A.OpenMenu(spec)
    local handled, universal = tryUniversal(spec)
    if handled then return universal end

    local options = spec and spec.options or {}
    if #options == 0 then return false end
    if #options == 1 and type(options[1].action) == 'function' then
        options[1].action()
        return true
    end

    menuGeneration = menuGeneration + 1
    local generation = menuGeneration
    CreateThread(function()
        local selected = 1
        local expiresAt = GetGameTimer() + 30000
        local numberControls = { 157, 158, 160, 164, 165, 159, 161, 162, 163 }
        while menuGeneration == generation and GetGameTimer() < expiresAt do
            local title = tostring(spec.label or 'Etkileşim')
            local label = tostring(options[selected].label or ('Seçenek ' .. selected))
            helpText(('~y~%s~s~~n~< %d/%d > %s~n~~INPUT_CELLPHONE_LEFT~ / ~INPUT_CELLPHONE_RIGHT~ Sec  ~INPUT_FRONTEND_ACCEPT~ Onayla  ~INPUT_FRONTEND_CANCEL~ Kapat')
                :format(title, selected, #options, label))

            if IsControlJustReleased(0, 174) or IsControlJustReleased(0, 172) then
                selected = selected > 1 and selected - 1 or #options
            elseif IsControlJustReleased(0, 175) or IsControlJustReleased(0, 173) then
                selected = selected < #options and selected + 1 or 1
            elseif IsControlJustReleased(0, 201) or IsControlJustReleased(0, 191) then
                menuGeneration = menuGeneration + 1
                local action = options[selected] and options[selected].action
                if type(action) == 'function' then pcall(action) end
                return
            elseif IsControlJustReleased(0, 202) or IsControlJustReleased(0, 177) then
                menuGeneration = menuGeneration + 1
                return
            elseif #options <= #numberControls then
                for index, control in ipairs(numberControls) do
                    if IsControlJustReleased(0, control) then
                        selected = index
                        break
                    end
                end
            end
            Wait(0)
        end
    end)
    return true
end

function A.Progress(data)
    return InternalUI.StartProgress(data)
end

function A.CancelProgress()
    return InternalUI.CancelProgress()
end

function A.SkillCheck(difficulty, inputs)
    return InternalUI.SkillCheck(difficulty, inputs)
end
