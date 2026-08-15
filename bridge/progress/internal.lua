if IsDuplicityVersion() then return end
ProgressAdapters = ProgressAdapters or {}
ProgressAdapters.internal = {}
local universalForwarding = false

local function tryUniversal(data)
    if universalForwarding then return false, nil end
    local adapter = ProgressAdapters.nui
    if type(adapter) ~= 'table' or type(adapter.Progress) ~= 'function' then return false, nil end

    universalForwarding = true
    local ok, result = pcall(adapter.Progress, data)
    universalForwarding = false
    return true, ok and result or false
end

function ProgressAdapters.internal.Progress(data)
    local handled, universal = tryUniversal(data or {})
    if handled then return universal end
    return InternalUI.StartProgress(data or {})
end

function ProgressAdapters.internal.CancelProgress()
    local adapter = ProgressAdapters.nui
    if not universalForwarding and type(adapter) == 'table' and type(adapter.CancelProgress) == 'function' then
        universalForwarding = true
        local ok, result = pcall(adapter.CancelProgress)
        universalForwarding = false
        if ok then return result == true end
    end
    return InternalUI.CancelProgress()
end
