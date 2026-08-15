-- Framework notification category delegates to active framework adapter.

NotifyAdapters = NotifyAdapters or {}
NotifyAdapters.framework = {}
local A = NotifyAdapters.framework

function A.Notify(...)
    if ActiveFrameworkAdapter and type(ActiveFrameworkAdapter.Notify) == 'function' then
        return ActiveFrameworkAdapter.Notify(...)
    end
    return NotifyAdapters.internal.Notify(...)
end

