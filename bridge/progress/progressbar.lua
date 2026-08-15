if IsDuplicityVersion() then return end
ProgressAdapters = ProgressAdapters or {}
ProgressAdapters.progressbar = {}
local A = ProgressAdapters.progressbar
local active

local function normalizeRequest(data)
    local input = type(data) == 'table' and data or {}
    local request = {}
    for key, value in pairs(input) do
        request[key] = value
    end

    local generic = type(input.disable) == 'table' and input.disable or {}
    local existing = type(input.controlDisables) == 'table' and input.controlDisables or {}
    request.controlDisables = {
        disableMovement = existing.disableMovement == true or generic.move == true or generic.movement == true,
        disableCarMovement = existing.disableCarMovement == true or generic.car == true or generic.carMovement == true,
        disableCombat = existing.disableCombat == true or generic.combat == true,
        disableMouse = existing.disableMouse == true or generic.mouse == true,
    }
    request.disable = nil
    return request
end

function A.Progress(data)
    if GetResourceState('progressbar') ~= 'started' then return ProgressAdapters.internal.Progress(data) end
    local request = promise.new()
    active = request
    local ok = pcall(function()
        exports['progressbar']:Progress(normalizeRequest(data), function(cancelled)
            request:resolve(cancelled ~= true)
        end)
    end)
    if not ok then active = nil; return ProgressAdapters.internal.Progress(data) end
    local result = Citizen.Await(request)
    if active == request then active = nil end
    return result == true
end

function A.CancelProgress()
    local ok = pcall(function() exports['progressbar']:Cancel() end)
    if active then active:resolve(false); active = nil end
    return ok
end
