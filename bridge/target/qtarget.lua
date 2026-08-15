-- qtarget adapter. API mirrors qb-target on supported qtarget releases.

if IsDuplicityVersion() then return end
TargetAdapters = TargetAdapters or {}
TargetAdapters.qtarget = {}
local A = TargetAdapters.qtarget

function A.RegisterInteractable(spec)
    return pcall(function()
        exports.qtarget:AddBoxZone(spec.id, spec.coords, spec.length or 2.5, spec.width or 2.5, {
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
    return pcall(function() exports.qtarget:RemoveZone(id) end)
end
