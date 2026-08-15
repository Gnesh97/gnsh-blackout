-- Legacy textUI target adapter. It is usable only when ox_lib exposes
-- points/showTextUI; otherwise loader selects standalone.

if IsDuplicityVersion() then return end
TargetAdapters = TargetAdapters or {}
TargetAdapters.textui = {}
local A = TargetAdapters.textui
local activePoints = {}

function A.RegisterInteractable(spec)
    if not lib or not lib.points or type(lib.points.new) ~= 'function' then return false end
    if activePoints[spec.id] then activePoints[spec.id]:remove() end

    local point = lib.points.new({ coords = spec.coords, distance = spec.distance or 2.0 })
    function point:onExit()
        if lib.hideTextUI then lib.hideTextUI() end
    end
    function point:nearby()
        local label = spec.label or (spec.options and spec.options[1] and spec.options[1].label) or 'Etkileşim'
        if lib.showTextUI then lib.showTextUI(('[E] %s'):format(label)) end
        if IsControlJustReleased(0, 38) then Bridge.OpenMenu(spec) end
    end
    activePoints[spec.id] = point
    return true
end

function A.RemoveInteractable(id)
    local point = activePoints[id]
    if point then point:remove() end
    activePoints[id] = nil
    if lib and lib.hideTextUI then lib.hideTextUI() end
    return true
end

