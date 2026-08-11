--[[
    bridge/framework/standalone.lua

    Always-available fallback framework adapter (spec §55). Used when no
    supported framework is detected, or when Config.Bridge.framework is
    explicitly set to 'standalone'. Guarantees the resource can start and
    run its core power-grid logic with zero external dependency — job/
    permission/item features degrade gracefully (permission checks fall
    back to FiveM ACE groups; item checks always fail closed).

    Shared file: branches on IsDuplicityVersion() rather than shipping as
    two separate client/server files, since the logic is a handful of
    lines either way.
]]

FrameworkAdapters = FrameworkAdapters or {}
FrameworkAdapters.standalone = {}

local A = FrameworkAdapters.standalone

if IsDuplicityVersion() then
    -- ── Server ──────────────────────────────────────────────────────────
    function A.GetPlayer(source)
        -- No player object concept without a framework; callers that only
        -- need to know "does this source exist" can check GetPlayerName.
        return GetPlayerName(source) and { source = source } or nil
    end

    function A.GetJob(_source)
        return nil -- no job system without a framework
    end

    function A.HasPermission(source, group)
        return IsPlayerAceAllowed(source, group) == true
    end

    -- No inventory without a framework — fail closed rather than silently
    -- granting/removing items that don't exist anywhere.
    function A.HasItem(_source, _item, _amount)
        return false
    end

    function A.RemoveItem(_source, _item, _amount)
        return false
    end

    function A.AddItem(_source, _item, _amount)
        return false
    end

    function A.Notify(source, message, _type)
        TriggerClientEvent('chat:addMessage', source, {
            args = { '[Infrastructure]', message },
        })
    end
else
    -- ── Client ──────────────────────────────────────────────────────────
    function A.Notify(message, _type)
        TriggerEvent('chat:addMessage', {
            args = { '[Infrastructure]', message },
        })
    end
end
