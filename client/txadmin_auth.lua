--[[
    client/txadmin_auth.lua

    Requests txAdmin's own server-side in-game authentication flow. The
    client only asks txAdmin to check the player's identifiers; it never
    supplies or receives an authorization decision for gnsh-blackout.
]]

local requestPending = false
local lastRequestAt = 0
local requestCooldownMs = 3000

local function requestTxAdminAuth()
    local monitorState = GetResourceState('monitor')
    local namedState = GetResourceState('txAdmin')
    if monitorState == 'missing' and namedState == 'missing' then return false end

    local now = GetGameTimer()
    if requestPending or now - lastRequestAt < requestCooldownMs then
        return false
    end

    requestPending = true
    lastRequestAt = now
    TriggerServerEvent('txsv:checkIfAdmin')

    SetTimeout(5000, function()
        requestPending = false
    end)
    return true
end

RegisterNetEvent('gnsh-blackout:client:requestTxAdminAuth', function()
    requestTxAdminAuth()
end)

RegisterCommand('blackoutauth', function()
    requestTxAdminAuth()
end, false)

RegisterCommand('blackoutadmin', function()
    TriggerServerEvent('gnsh-blackout:server:requestAdminPanel')
end, false)

local function scheduleAuthRequest()
    CreateThread(function()
        Wait(1000)
        requestTxAdminAuth()
    end)
end

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        scheduleAuthRequest()
    end
end)

if GetResourceState(GetCurrentResourceName()) == 'started' then
    scheduleAuthRequest()
end
