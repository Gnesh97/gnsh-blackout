-- ox_lib notification adapter. It is selected only while lib.notify exists.

NotifyAdapters = NotifyAdapters or {}
NotifyAdapters.ox_lib = {}
local A = NotifyAdapters.ox_lib

if IsDuplicityVersion() then
    function A.Notify(source, message, notifyType)
        TriggerClientEvent('gnsh-blackout:client:notify', source, message, notifyType or 'info')
        return true
    end
else
    function A.Notify(message, notifyType)
        if OxLibBridge and type(OxLibBridge.Call) == 'function' then
            local ok = OxLibBridge.Call('notify', { description = tostring(message), type = notifyType or 'inform' })
            if ok then return true end
        end
        return NotifyAdapters.internal.Notify(message, notifyType)
    end
end
