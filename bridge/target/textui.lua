--[[
    bridge/target/textui.lua

    ox_lib textUI adapter (client-only) — no qb-target dependency. This is
    the sensible default on this server: server.cfg sets
    `setr UseTarget false`, meaning targeting is disabled server-wide even
    though qb-target is installed.

    Implemented with lib.points (proximity trigger) + lib.showTextUI/
    hideTextUI + a bound keybind (default E) to activate the closest
    option, matching the same RegisterInteractable/RemoveInteractable
    contract as bridge/target/qb_target.lua so callers never branch on
    which adapter is active.

    BUGFIX (live testing, 2026-08-08): the per-tick callback MUST be
    named `nearby` — that's not a free choice, it's the exact field name
    ox_lib's own points loop polls (imports/points/client.lua:117-118:
    `if point.nearby then point:nearby() end`). The original version of
    this file used `nearby` as a boolean "am I in range" flag instead,
    which overwrote ox_lib's own callback slot the first time onEnter
    fired — the very next SetInterval tick then tried to call that
    boolean as a function and crashed with "attempt to call a boolean
    value (method 'nearby')", silently breaking every interactable using
    this adapter (which, on THIS server, is every one of them — see
    bridge/loader.lua's resolveTargetKey(): UseTarget is false and ox_lib
    is running, so textui wins over qb-target/standalone by default).
    Multi-option support (menuv) was also missing entirely here; ported
    from bridge/target/standalone.lua via the shared
    bridge/target/menu_helper.lua so both adapters share one place a
    future NUI replaces.
]]

if IsDuplicityVersion() then return end

TargetAdapters = TargetAdapters or {}
TargetAdapters.textui = {}

local A = TargetAdapters.textui
local activePoints = {}

function A.RegisterInteractable(spec)
    if activePoints[spec.id] then
        activePoints[spec.id]:remove()
    end

    local point = lib.points.new({
        coords = spec.coords,
        distance = spec.distance or 2.0,
    })

    function point:onExit()
        lib.hideTextUI()
    end

    -- Field name `nearby` is required by ox_lib itself (see BUGFIX note
    -- at the top of this file) — this is polled every 300ms by ox_lib's
    -- own points loop while the point is in range, not called by us.
    function point:nearby()
        local label = spec.label or (spec.options and spec.options[1] and spec.options[1].label) or 'Etkileşim'
        lib.showTextUI(('[E] %s'):format(label))
        if IsControlJustReleased(0, 38) then -- INPUT_PICKUP (E)
            MenuHelper.OpenOptions(spec)
        end
    end

    activePoints[spec.id] = point
end

function A.RemoveInteractable(id)
    local point = activePoints[id]
    if point then
        point:remove()
        activePoints[id] = nil
    end
end
