-- Optional client-side exports for soft bridge dependencies.
--
-- FiveM resources have isolated Lua environments. ox_lib's public UI API is
-- exposed through resource exports, so it must be called through exports.ox_lib
-- rather than assuming another resource's `lib` global exists here.

if IsDuplicityVersion() then return end

OxLibBridge = OxLibBridge or {}
local O = OxLibBridge

local function started()
    return type(GetResourceState) == 'function' and GetResourceState('ox_lib') == 'started'
end

local function exportFunction(name)
    if not started() then return nil end

    local ok, fn = pcall(function()
        return exports['ox_lib'][name]
    end)
    if not ok or type(fn) ~= 'function' then return nil end
    return fn
end

function O.IsAvailable(name)
    return exportFunction(name) ~= nil
end

function O.Call(name, ...)
    local fn = exportFunction(name)
    if not fn then return false, nil end

    local ok, result = pcall(fn, ...)
    if ok then return true, result end

    -- Keep compatibility with runtimes that expose an export proxy requiring
    -- its owner as the first argument when accessed dynamically.
    local owner = exports['ox_lib']
    local retryOk, retryResult = pcall(fn, owner, ...)
    if retryOk then return true, retryResult end
    return false, nil
end

local function signalReady()
    if type(TriggerEvent) == 'function' then
        TriggerEvent('gnsh-blackout:client:optionalBridgeReady', 'ox_lib')
    end
end

-- Resource start order inside a bracketed group is not a safe readiness
-- boundary. Retry after the current client tick as well as on ox_lib start.
if type(CreateThread) == 'function' and type(Wait) == 'function' then
    CreateThread(function()
        Wait(0)
        signalReady()
    end)
end

if type(AddEventHandler) == 'function' then
    AddEventHandler('onResourceStart', function(resourceName)
        if resourceName == 'ox_lib' then
            CreateThread(function()
                Wait(0)
                signalReady()
            end)
        end
    end)
end
