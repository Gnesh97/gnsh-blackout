-- qb-target adapter. Loader rebinds registered specs when target resources
-- start or stop, so this adapter never owns a duplicate fallback zone.

if IsDuplicityVersion() then return end
TargetAdapters = TargetAdapters or {}
TargetAdapters.qb_target = {}
local A = TargetAdapters.qb_target

function A.RegisterInteractable(spec)
    return pcall(function()
        exports['qb-target']:AddBoxZone(spec.id, spec.coords, spec.length or 2.5, spec.width or 2.5, {
            name = spec.id,
            heading = spec.heading or 0.0,
            debugPoly = false,
            minZ = (spec.coords.z or 0) - 2.0,
            maxZ = (spec.coords.z or 0) + 3.0,
        }, {
            options = {
                {
                    icon = 'fa-solid fa-bolt',
                    label = spec.label or 'Altyapı Kontrolü',
                    action = function()
                        if Bridge and type(Bridge.OpenMenu) == 'function' then Bridge.OpenMenu(spec) end
                    end,
                },
            },
            distance = spec.distance or 4.0,
        })
    end)
end

function A.RemoveInteractable(id)
    return pcall(function() exports['qb-target']:RemoveZone(id) end)
end
