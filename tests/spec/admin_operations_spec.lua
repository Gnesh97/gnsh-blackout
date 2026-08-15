-- Phase 30 command contract tests. Runtime mutations are exercised in-game.

TEST('admin operation command surface uses explicit targets', function()
    local required = {
        setgridstate = true,
        setsubstationstate = true,
        setfeederstate = true,
        restoregrid = true,
        restoresubstation = true,
        restorefeeder = true,
        restoretransformer = true,
        createincident = true,
        resolveincident = true,
        reloadtopology = true,
        resyncvisual = true,
        repairall = true,
        blackout_city = true,
        restore_city = true,
        blackout_towns = true,
        restore_towns = true,
        blackout_south = true,
        restore_south = true,
        blackout_vinewood = true,
        restore_vinewood = true,
        blackout_north = true,
        restore_north = true,
    }

    for _, name in ipairs(AdminOperations.CommandNames) do
        required[name] = nil
    end
    for name, missing in pairs(required) do
        ASSERT_FALSE(missing, 'missing admin command: ' .. name)
    end
end)
