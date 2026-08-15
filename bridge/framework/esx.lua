-- ESX Legacy adapter.

FrameworkAdapters = FrameworkAdapters or {}
FrameworkAdapters.esx = {}

local A = FrameworkAdapters.esx
local ESX

local function shared()
    if type(GetResourceState) == 'function' and GetResourceState('es_extended') ~= 'started' then
        ESX = nil
        return nil
    end
    if ESX then return ESX end
    local ok, value = pcall(function() return exports.es_extended:getSharedObject() end)
    if ok then ESX = value end
    return ESX
end

if IsDuplicityVersion() then
    function A.GetPlayer(source)
        local value = shared()
        if not value or type(value.GetPlayerFromId) ~= 'function' then return nil end
        local ok, player = pcall(value.GetPlayerFromId, source)
        return ok and player or nil
    end

    function A.GetJob(source)
        local player = A.GetPlayer(source)
        local job = player and (type(player.getJob) == 'function' and player.getJob() or player.job)
        return type(job) == 'table' and job.name or job
    end

    function A.HasPermission(source, group)
        return IsPlayerAceAllowed(source, group) == true
    end

    function A.Notify(source, message, notifyType)
        local player = A.GetPlayer(source)
        if player and type(player.showNotification) == 'function' then
            pcall(player.showNotification, message, notifyType)
        else
            TriggerClientEvent('chat:addMessage', source, { args = { '[Infrastructure]', message } })
        end
    end

    function A.HasItem(source, item, amount)
        local player = A.GetPlayer(source)
        if not player or type(player.getInventoryItem) ~= 'function' then return false end
        local ok, entry = pcall(player.getInventoryItem, item)
        return ok and entry and (tonumber(entry.count) or 0) >= (amount or 1) or false
    end

    function A.RemoveItem(source, item, amount)
        local player = A.GetPlayer(source)
        if not player or type(player.removeInventoryItem) ~= 'function' then return false, 'framework inventory remove unavailable' end
        return pcall(player.removeInventoryItem, item, amount or 1)
    end

    function A.AddItem(source, item, amount)
        local player = A.GetPlayer(source)
        if not player or type(player.addInventoryItem) ~= 'function' then return false, 'framework inventory add unavailable' end
        return pcall(player.addInventoryItem, item, amount or 1)
    end
else
    function A.GetPlayerData()
        local value = shared()
        if not value or type(value.GetPlayerData) ~= 'function' then return nil end
        local ok, data = pcall(value.GetPlayerData)
        return ok and data or nil
    end

    function A.Notify(message, notifyType)
        local value = shared()
        if value and type(value.ShowNotification) == 'function' then
            pcall(value.ShowNotification, message, notifyType)
        else
            TriggerEvent('chat:addMessage', { args = { '[Infrastructure]', message } })
        end
    end
end
