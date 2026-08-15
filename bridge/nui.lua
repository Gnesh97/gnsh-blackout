-- Framework-independent NUI adapter.
-- One resource-owned UI keeps menu, progress, skillcheck and notifications
-- visually consistent across QBCore, Qbox, ESX and standalone servers.

NotifyAdapters = NotifyAdapters or {}

if IsDuplicityVersion() then
    NotifyAdapters.nui = {}
    function NotifyAdapters.nui.Notify(source, message, notifyType)
        TriggerClientEvent('gnsh-blackout:client:notify', source, message, notifyType or 'info')
        return true
    end
    return
end

MenuAdapters = MenuAdapters or {}
ProgressAdapters = ProgressAdapters or {}
SkillcheckAdapters = SkillcheckAdapters or {}

MenuAdapters.nui = {}
ProgressAdapters.nui = {}
SkillcheckAdapters.nui = {}
NotifyAdapters.nui = {}

local Menu = MenuAdapters.nui
local Progress = ProgressAdapters.nui
local Skillcheck = SkillcheckAdapters.nui
local Notify = NotifyAdapters.nui

local sequence = 0
local active = {
    menu = nil,
    progress = nil,
    skillcheck = nil,
    admin = nil,
}
local focusOwner

local function nextToken(prefix)
    sequence = sequence + 1
    return ('nui:%s:%d:%d'):format(prefix, GetGameTimer(), sequence)
end

local function send(message)
    if type(SendNUIMessage) ~= 'function' then return false end
    local ok = pcall(SendNUIMessage, message)
    return ok
end

local function focus(cursor, token)
    if type(SetNuiFocus) ~= 'function' then return false end
    SetNuiFocus(true, cursor == true)
    if type(SetNuiFocusKeepInput) == 'function' then SetNuiFocusKeepInput(false) end
    focusOwner = token
    return true
end

local function releaseFocus(token)
    if token and focusOwner and token ~= focusOwner then return false end
    local hadFocus = focusOwner ~= nil
    if type(SetNuiFocus) == 'function' then SetNuiFocus(false, false) end
    if type(SetNuiFocusKeepInput) == 'function' then SetNuiFocusKeepInput(false) end
    focusOwner = nil
    return hadFocus
end

local function resolve(slot, result)
    local pending = active[slot]
    active[slot] = nil
    if pending and pending.request then pending.request:resolve(result == true) end
end

local function closeAll()
    local owner = focusOwner
    resolve('progress', false)
    resolve('skillcheck', false)
    active.menu = nil
    active.admin = nil
    send({ action = 'closeAll' })
    releaseFocus(owner)
end

local function fallback(category, method, ...)
    local adapters = _G[category]
    local adapter = adapters and adapters.internal
    local implementation = adapter and adapter[method]
    if type(implementation) == 'function' then return implementation(...) end
    return false
end

local function validToken(value, pending)
    return pending and type(value) == 'string' and #value <= 96 and value == pending.token
end

-- A resource restart can reload Lua while the browser surface survives for a
-- frame. Clear stale panels/focus before the first interaction is possible.
CreateThread(function()
    Wait(0)
    closeAll()
    releaseFocus()
end)

local function copyOptions(options)
    local result = {}
    for index, option in ipairs(options or {}) do
        if type(option) == 'table' then
            result[index] = {
                action = option.action,
                label = tostring(option.label or ('Seçenek ' .. index)),
                description = option.description and tostring(option.description) or nil,
                icon = option.icon and tostring(option.icon) or nil,
                tone = option.tone and tostring(option.tone) or nil,
                disabled = option.disabled == true,
            }
        end
    end
    return result
end

local function menuPayload(spec, token, options)
    local visible = {}
    for index, option in ipairs(options) do
        visible[index] = {
            index = index,
            label = option.label,
            description = option.description,
            icon = option.icon,
            tone = option.tone,
            disabled = option.disabled,
        }
    end
    local powered = not (ClientState and ClientState.CurrentPowered == false)
    return {
        action = 'openMenu',
        token = token,
        title = tostring(spec.label or spec.title or 'Altyapı Kontrolü'),
        subtitle = tostring(spec.subtitle or 'Operasyon seçin'),
        variant = tostring(spec.variant or 'infrastructure'),
        linkUnstable = not powered,
        options = visible,
    }
end

function Menu.OpenMenu(spec)
    if type(spec) ~= 'table' or type(spec.options) ~= 'table' or #spec.options == 0 then return false end
    local options = copyOptions(spec.options)
    closeAll()

    local token = nextToken('menu')
    active.menu = { token = token, options = options }
    if not send(menuPayload(spec, token, options)) then
        active.menu = nil
        releaseFocus(token)
        return fallback('MenuAdapters', 'OpenMenu', spec)
    end

    focus(true, token)
    return true
end

function Menu.CloseMenu()
    local token = active.menu and active.menu.token
    active.menu = nil
    send({ action = 'closeMenu' })
    releaseFocus(token)
    return true
end

AdminUI = AdminUI or {}

function AdminUI.Open(payload)
    closeAll()

    local token = nextToken('admin')
    local message = type(payload) == 'table' and {} or {}
    for key, value in pairs(payload or {}) do message[key] = value end
    message.action = 'adminOpen'
    message.token = token

    active.admin = { token = token }
    if not send(message) then
        active.admin = nil
        releaseFocus(token)
        return false
    end

    focus(true, token)
    return true
end

function AdminUI.Update(payload)
    local pending = active.admin
    if not pending or type(payload) ~= 'table' then return false end
    local message = {}
    for key, value in pairs(payload) do message[key] = value end
    message.action = 'adminData'
    message.token = pending.token
    return send(message)
end

function AdminUI.Close()
    local pending = active.admin
    if not pending then return false end
    active.admin = nil
    send({ action = 'adminClose' })
    releaseFocus(pending.token)
    return true
end

local function disableControls(disable)
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

local function lockControls(slot, token, disable)
    if type(disable) ~= 'table' then return end
    CreateThread(function()
        while active[slot] and active[slot].token == token do
            disableControls(disable)
            Wait(0)
        end
    end)
end

function Progress.Progress(data)
    data = type(data) == 'table' and data or {}
    local duration = math.max(0, tonumber(data.duration) or 0)
    local canCancel = data.canCancel ~= false
    closeAll()

    local request = promise.new()
    local token = nextToken('progress')
    active.progress = {
        token = token,
        request = request,
        startedAt = GetGameTimer(),
        duration = duration,
        canCancel = canCancel,
    }
    local sent = send({
        action = 'progress',
        token = token,
        duration = duration,
        label = tostring(data.label or 'İşlem sürüyor'),
        variant = tostring(data.variant or 'operation'),
        stage = data.stage and tostring(data.stage) or nil,
        stageIndex = tonumber(data.stageIndex),
        totalStages = tonumber(data.totalStages),
        canCancel = canCancel,
    })
    if not sent then
        active.progress = nil
        releaseFocus(token)
        return fallback('ProgressAdapters', 'Progress', data)
    end

    if canCancel then focus(false, token) end
    lockControls('progress', token, data.disable)
    CreateThread(function()
        Wait(math.max(5000, duration + 5000))
        if active.progress and active.progress.token == token then resolve('progress', false) end
    end)
    local completed = Citizen.Await(request) == true
    if active.progress and active.progress.token == token then active.progress = nil end
    send({ action = 'closeProgress' })
    releaseFocus(token)
    return completed
end

function Progress.CancelProgress()
    local token = active.progress and active.progress.token
    if not token then return false end
    resolve('progress', false)
    send({ action = 'closeProgress' })
    releaseFocus(token)
    return true
end

function Skillcheck.SkillCheck(difficulty, inputs, metadata)
    closeAll()

    local request = promise.new()
    local token = nextToken('skillcheck')
    active.skillcheck = { token = token, request = request, startedAt = GetGameTimer() }
    local sent = send({
        action = 'skillcheck',
        token = token,
        difficulty = type(difficulty) == 'table' and difficulty or { difficulty or 'easy' },
        inputs = type(inputs) == 'table' and inputs or { 'e' },
        title = type(metadata) == 'table' and metadata.title or 'Güvenlik doğrulaması',
        variant = type(metadata) == 'table' and metadata.variant or 'security',
    })
    if not sent then
        active.skillcheck = nil
        releaseFocus(token)
        return fallback('SkillcheckAdapters', 'SkillCheck', difficulty, inputs)
    end

    focus(false, token)
    local stageCount = type(difficulty) == 'table' and #difficulty or 1
    CreateThread(function()
        Wait(math.max(5000, stageCount * 3000 + 5000))
        if active.skillcheck and active.skillcheck.token == token then resolve('skillcheck', false) end
    end)
    local result = Citizen.Await(request) == true
    if active.skillcheck and active.skillcheck.token == token then active.skillcheck = nil end
    send({ action = 'closeSkillcheck' })
    releaseFocus(token)
    return result
end

function Notify.Notify(message, notifyType)
    if send({
        action = 'notify',
        message = tostring(message or ''),
        type = tostring(notifyType or 'info'),
    }) then
        return true
    end
    return fallback('NotifyAdapters', 'Notify', message, notifyType)
end

local function registerCallback(name, handler)
    if type(RegisterNUICallback) ~= 'function' then return end
    RegisterNUICallback(name, function(data, callback)
        local ok, result = pcall(handler, type(data) == 'table' and data or {})
        if not ok then
            print(('^1[gnsh-blackout] NUI callback %s failed: %s^7'):format(name, tostring(result)))
            result = false
        end
        if callback then callback({ ok = result == true }) end
    end)
end

registerCallback('menuSelect', function(data)
    local pending = active.menu
    local index = tonumber(data.index)
    if not validToken(data.token, pending) or not index or index % 1 ~= 0 then return false end

    local option = pending.options[index]
    active.menu = nil
    send({ action = 'closeMenu' })
    releaseFocus(pending.token)
    if option and option.disabled ~= true and type(option.action) == 'function' then
        pcall(option.action)
    end
    return option ~= nil and option.disabled ~= true
end)

registerCallback('menuClose', function(data)
    if not validToken(data.token, active.menu) then return false end
    local token = active.menu.token
    active.menu = nil
    send({ action = 'closeMenu' })
    releaseFocus(token)
    return true
end)

registerCallback('adminClose', function(data)
    local pending = active.admin
    if not validToken(data.token, pending) then return false end
    active.admin = nil
    send({ action = 'adminClose' })
    releaseFocus(pending.token)
    return true
end)

registerCallback('adminRefresh', function(data)
    local pending = active.admin
    if not validToken(data.token, pending) then return false end
    TriggerServerEvent('gnsh-blackout:server:requestAdminSnapshot')
    return true
end)

registerCallback('adminCommand', function(data)
    local pending = active.admin
    if not validToken(data.token, pending) or type(data.command) ~= 'string' then return false end
    if #data.command == 0 or #data.command > 64 then return false end
    if data.args ~= nil and type(data.args) ~= 'table' then return false end
    TriggerServerEvent('gnsh-blackout:server:adminCommand', data.command, data.args or {})
    return true
end)

registerCallback('progressComplete', function(data)
    local pending = active.progress
    if not validToken(data.token, pending) then return false end
    local elapsed = GetGameTimer() - pending.startedAt
    if elapsed + 75 < pending.duration then return false end
    resolve('progress', true)
    return true
end)

registerCallback('progressCancel', function(data)
    local pending = active.progress
    if not validToken(data.token, pending) or pending.canCancel ~= true then return false end
    resolve('progress', false)
    return true
end)

registerCallback('skillResult', function(data)
    if not validToken(data.token, active.skillcheck) then return false end
    resolve('skillcheck', data.success == true)
    return true
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    closeAll()
end)
