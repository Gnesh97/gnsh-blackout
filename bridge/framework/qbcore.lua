--[[
    bridge/framework/qbcore.lua

    QBCore framework adapter (spec §55). This server has qb-core 1.3.0
    running (verified in [qb]/qb-core/fxmanifest.lua) — this is the
    adapter auto-detection will pick by default.

    Uses the standard QBCore.Functions.GetCoreObject() export pattern.
]]

FrameworkAdapters = FrameworkAdapters or {}
FrameworkAdapters.qbcore = {}

local A = FrameworkAdapters.qbcore
local QBCore = nil

local function core()
    if not QBCore then
        QBCore = exports['qb-core']:GetCoreObject()
    end
    return QBCore
end

if IsDuplicityVersion() then
    -- ── Server ──────────────────────────────────────────────────────────
    function A.GetPlayer(source)
        return core().Functions.GetPlayer(source)
    end

    function A.GetJob(source)
        local Player = A.GetPlayer(source)
        return Player and Player.PlayerData.job and Player.PlayerData.job.name or nil
    end

    function A.HasPermission(source, group)
        local ok, result = pcall(function()
            return core().Functions.HasPermission(source, group)
        end)
        -- txAdmin/ACE identities are independent from the QBCore permission
        -- table. A false QBCore result must not suppress a valid ACE grant.
        if ok and result == true then return true end
        -- Older/newer qb-core builds vary on HasPermission's exact
        -- signature; ACE group is the universal fallback.
        return IsPlayerAceAllowed(source, group) == true
    end

    -- Item calls route through the inventory bridge (bridge/inventory/*),
    -- not here — QBCore itself doesn't own inventory once ox_inventory is
    -- in play (this server has inventory:framework "qb" pointed at
    -- ox_inventory). These are intentionally left unimplemented so a
    -- caller mistakenly reaching into the framework adapter for items
    -- fails loudly instead of silently doing the wrong thing.

    function A.Notify(source, message, notifyType)
        local Player = A.GetPlayer(source)
        if Player then
            TriggerClientEvent('QBCore:Notify', source, message, notifyType or 'primary')
        else
            TriggerClientEvent('chat:addMessage', source, { args = { '[Infrastructure]', message } })
        end
    end
else
    -- ── Client ──────────────────────────────────────────────────────────
    function A.GetPlayerData()
        return core().Functions.GetPlayerData()
    end

    function A.Notify(message, notifyType)
        core().Functions.Notify(message, notifyType or 'primary')
    end
end
