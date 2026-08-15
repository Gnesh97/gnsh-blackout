-- qbx_core adapter. ACE is the authoritative permission source.

FrameworkAdapters = FrameworkAdapters or {}
FrameworkAdapters.qbox = {}

local A = FrameworkAdapters.qbox

local function getPlayer(source)
    local ok, player = pcall(function() return exports.qbx_core:GetPlayer(source) end)
    return ok and player or nil
end

local function dataOf(player)
    return player and (player.PlayerData or player) or nil
end

if IsDuplicityVersion() then
    function A.GetPlayer(source)
        return getPlayer(source)
    end

    function A.GetJob(source)
        local data = dataOf(getPlayer(source))
        local job = data and data.job
        return type(job) == 'table' and job.name or job
    end

    function A.HasPermission(source, group)
        return IsPlayerAceAllowed(source, group) == true
    end

    function A.Notify(source, message, notifyType)
        local ok = pcall(function()
            exports.qbx_core:Notify(source, message, notifyType or 'inform')
        end)
        if not ok then TriggerClientEvent('chat:addMessage', source, { args = { '[Infrastructure]', message } }) end
    end

    function A.HasItem(source, item, amount)
        local player = getPlayer(source)
        local fn = player and player.Functions and player.Functions.GetItemByName
        local entry = type(fn) == 'function' and fn(player, item) or nil
        return entry ~= nil and (tonumber(entry.amount or entry.count) or 0) >= (amount or 1)
    end

    function A.RemoveItem(source, item, amount)
        local player = getPlayer(source)
        local fn = player and player.Functions and player.Functions.RemoveItem
        if type(fn) ~= 'function' then return false, 'framework inventory remove unavailable' end
        local ok, result = pcall(fn, player, item, amount or 1)
        return ok and result ~= false or false
    end

    function A.AddItem(source, item, amount)
        local player = getPlayer(source)
        local fn = player and player.Functions and player.Functions.AddItem
        if type(fn) ~= 'function' then return false, 'framework inventory add unavailable' end
        local ok, result = pcall(fn, player, item, amount or 1)
        return ok and result ~= false or false
    end
else
    function A.GetPlayerData()
        local ok, data = pcall(function() return exports.qbx_core:GetPlayerData() end)
        return ok and data or nil
    end

    function A.Notify(message, notifyType)
        local ok = pcall(function() exports.qbx_core:Notify(message, notifyType or 'inform') end)
        if not ok then TriggerEvent('chat:addMessage', { args = { '[Infrastructure]', message } }) end
    end
end

