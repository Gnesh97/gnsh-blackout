--[[
    bridge/inventory/qb.lua

    Legacy qb-inventory adapter (via QBCore.Functions item helpers). Not
    the active adapter on this server (ox_inventory is running), but kept
    so the resource stays portable to servers still on qb-inventory
    (RULE 8: core must not hard-depend on one inventory system).
]]

if not IsDuplicityVersion() then return end

InventoryAdapters = InventoryAdapters or {}
InventoryAdapters.qb = {}

local A = InventoryAdapters.qb
local QBCore = nil

local function core()
    if not QBCore then
        QBCore = exports['qb-core']:GetCoreObject()
    end
    return QBCore
end

function A.HasItem(source, item, amount)
    local Player = core().Functions.GetPlayer(source)
    if not Player then return false end
    return Player.Functions.GetItemByName(item) ~= nil
        and (Player.Functions.GetItemByName(item).amount or 0) >= (amount or 1)
end

function A.RemoveItem(source, item, amount)
    local Player = core().Functions.GetPlayer(source)
    if not Player then return false end
    return Player.Functions.RemoveItem(item, amount or 1) == true
end

function A.AddItem(source, item, amount)
    local Player = core().Functions.GetPlayer(source)
    if not Player then return false end
    return Player.Functions.AddItem(item, amount or 1) == true
end
