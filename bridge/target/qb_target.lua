--[[
    bridge/target/qb_target.lua

    qb-target adapter (client-only). Wraps AddBoxZone/RemoveZone from
    qb-target's registration.lua export surface. Also registers with the
    standalone 3D Marker/Text loop to ensure interaction works even if
    targeting is disabled in server.cfg.
]]

if IsDuplicityVersion() then return end

TargetAdapters = TargetAdapters or {}
TargetAdapters.qb_target = {}

local A = TargetAdapters.qb_target

function A.RegisterInteractable(spec)
    pcall(function()
        exports['qb-target']:AddBoxZone(
            spec.id,
            spec.coords,
            spec.length or 2.5,
            spec.width or 2.5,
            {
                name = spec.id,
                heading = spec.heading or 0.0,
                debugPoly = false,
                minZ = (spec.coords.z or 0) - 2.0,
                maxZ = (spec.coords.z or 0) + 3.0,
            },
            {
                options = spec.options or {},
                distance = spec.distance or 4.0,
            }
        )
    end)

    -- Register with standalone fallback loop as well
    if TargetAdapters.standalone then
        TargetAdapters.standalone.RegisterInteractable(spec)
    end
end

function A.RemoveInteractable(id)
    pcall(function()
        exports['qb-target']:RemoveZone(id)
    end)
    if TargetAdapters.standalone then
        TargetAdapters.standalone.RemoveInteractable(id)
    end
end
