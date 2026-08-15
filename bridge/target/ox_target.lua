-- ox_target addBoxZone/removeZone adapter.

if IsDuplicityVersion() then return end
TargetAdapters = TargetAdapters or {}
TargetAdapters.ox_target = {}
local A = TargetAdapters.ox_target
local ids = {}

local function optionsFor(spec)
    return {
        {
            name = spec.id .. ':menu',
            icon = 'fa-solid fa-bolt',
            label = spec.label or 'Altyapı Kontrolü',
            distance = spec.distance,
            onSelect = function()
                if Bridge and type(Bridge.OpenMenu) == 'function' then Bridge.OpenMenu(spec) end
            end,
        },
    }
end

function A.RegisterInteractable(spec)
    if ids[spec.id] then A.RemoveInteractable(spec.id) end
    local ok, id = pcall(function()
        return exports.ox_target:addBoxZone({
            name = spec.id,
            coords = spec.coords,
            size = vector3(spec.length or 2.5, spec.width or 2.5, spec.height or 4.0),
            rotation = spec.heading or 0.0,
            debug = false,
            drawSprite = false,
            options = optionsFor(spec),
        })
    end)
    if ok then ids[spec.id] = id or spec.id end
    return ok
end

function A.RemoveInteractable(specId)
    local id = ids[specId] or specId
    ids[specId] = nil
    return pcall(function() exports.ox_target:removeZone(id) end)
end
