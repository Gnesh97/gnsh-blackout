-- Internal notification route. It forwards to the resource-owned NUI first;
-- the native feed/chat renderer remains the last-resort fallback.

NotifyAdapters = NotifyAdapters or {}
NotifyAdapters.internal = {}
local A = NotifyAdapters.internal

if IsDuplicityVersion() then
    function A.Notify(source, message, notifyType)
        TriggerClientEvent('gnsh-blackout:client:notify', source, message, notifyType or 'info')
        return true
    end
else
    local universalForwarding = false

    local function tryUniversal(message, notifyType)
        if universalForwarding then return false, nil end
        local adapter = NotifyAdapters.nui
        if type(adapter) ~= 'table' or type(adapter.Notify) ~= 'function' then return false, nil end

        universalForwarding = true
        local ok, result = pcall(adapter.Notify, message, notifyType)
        universalForwarding = false
        return true, ok and result or false
    end

    function A.Notify(message, notifyType)
        local handled, universal = tryUniversal(message, notifyType)
        if handled then return universal end

        local colors = { success = '~g~', error = '~r~', warning = '~y~', info = '~b~' }
        local prefix = colors[notifyType] or colors.info
        local ok = pcall(function()
            BeginTextCommandThefeedPost('STRING')
            AddTextComponentSubstringPlayerName(prefix .. '[Infrastructure]~s~ ' .. tostring(message))
            EndTextCommandThefeedPostTicker(false, false)
        end)
        if not ok then
            TriggerEvent('chat:addMessage', { args = { '[Infrastructure]', tostring(message) } })
        end
        return true
    end

    RegisterNetEvent('gnsh-blackout:client:notify', function(message, notifyType)
        local selected = Bridge and Bridge.AdapterInfo and Bridge.AdapterInfo.notify or 'internal'
        local adapter = NotifyAdapters[selected] or NotifyAdapters.internal
        if adapter and type(adapter.Notify) == 'function' then
            adapter.Notify(message, notifyType)
        end
    end)
end
