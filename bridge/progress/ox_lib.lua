if IsDuplicityVersion() then return end
ProgressAdapters = ProgressAdapters or {}
ProgressAdapters.ox_lib = {}
local A = ProgressAdapters.ox_lib

function A.Progress(data)
    if OxLibBridge and type(OxLibBridge.Call) == 'function' then
        local ok, result = OxLibBridge.Call('progressBar', data or {})
        if ok then return result ~= false end
    end
    return ProgressAdapters.internal.Progress(data)
end

function A.CancelProgress()
    if OxLibBridge and type(OxLibBridge.Call) == 'function' then
        local ok = OxLibBridge.Call('cancelProgress')
        if ok then return true end
    end
    return ProgressAdapters.internal.CancelProgress()
end
