-- QBCore framework adapter. Vendor calls are guarded so qb-core may start
-- or stop after this resource and the bridge can rebuild safely.

FrameworkAdapters = FrameworkAdapters or {}
FrameworkAdapters.qbcore = {}

local A = FrameworkAdapters.qbcore
local QBCore

local function core()
    if type(GetResourceState) == 'function' and GetResourceState('qb-core') ~= 'started' then
        QBCore = nil
        return nil
    end
    if QBCore then return QBCore end
    local ok, value = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if ok then QBCore = value end
    return QBCore
end

if IsDuplicityVersion() then
    function A.GetPlayer(source)
        local value = core()
        if not value or not value.Functions then return nil end
        local ok, player = pcall(value.Functions.GetPlayer, source)
        return ok and player or nil
    end

    function A.GetJob(source)
        local player = A.GetPlayer(source)
        return player and player.PlayerData and player.PlayerData.job
            and player.PlayerData.job.name or nil
    end

    function A.HasPermission(source, group)
        local value = core()
        if value and value.Functions and type(value.Functions.HasPermission) == 'function' then
            local ok, result = pcall(value.Functions.HasPermission, source, group)
            if ok and result == true then return true end
        end
        return IsPlayerAceAllowed(source, group) == true
    end

    function A.Notify(source, message, notifyType)
        local player = A.GetPlayer(source)
        if player then
            TriggerClientEvent('QBCore:Notify', source, message, notifyType or 'primary')
        else
            TriggerClientEvent('chat:addMessage', source, { args = { '[Infrastructure]', message } })
        end
    end

    function A.HasItem(source, item, amount)
        local player = A.GetPlayer(source)
        local fn = player and player.Functions and player.Functions.GetItemByName
        local entry = type(fn) == 'function' and fn(item) or nil
        return entry ~= nil and (tonumber(entry.amount or entry.count) or 0) >= (amount or 1)
    end

    function A.RemoveItem(source, item, amount)
        local player = A.GetPlayer(source)
        local fn = player and player.Functions and player.Functions.RemoveItem
        if type(fn) ~= 'function' then return false, 'framework inventory remove unavailable' end
        local ok, result = pcall(fn, item, amount or 1)
        return ok and result ~= false or false
    end

    function A.AddItem(source, item, amount)
        local player = A.GetPlayer(source)
        local fn = player and player.Functions and player.Functions.AddItem
        if type(fn) ~= 'function' then return false, 'framework inventory add unavailable' end
        local ok, result = pcall(fn, item, amount or 1)
        return ok and result ~= false or false
    end
else
    function A.GetPlayerData()
        local value = core()
        if not value or not value.Functions then return nil end
        local ok, data = pcall(value.Functions.GetPlayerData)
        return ok and data or nil
    end

    function A.Notify(message, notifyType)
        local value = core()
        if value and value.Functions and type(value.Functions.Notify) == 'function' then
            pcall(value.Functions.Notify, message, notifyType or 'primary')
        else
            TriggerEvent('chat:addMessage', { args = { '[Infrastructure]', message } })
        end
    end
end
