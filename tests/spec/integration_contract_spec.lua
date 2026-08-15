-- Phase 32 citywide integration contract tests.

TEST('citywide integration keeps versioned power event contracts', function()
    ASSERT_TRUE(Constants.EVENT_VERSION >= 1)
    ASSERT_EQ(Constants.StateKey.GRID, 'infra:grid:')
    ASSERT_EQ(Constants.StateKey.DISTRICT, 'infra:district:')
    ASSERT_TRUE(type(Config.Dispatch) == 'table')
    ASSERT_TRUE(Config.Dispatch.emitInternalEvent ~= false)
end)

TEST('optional bridge integrations do not require a hard dispatch resource', function()
    ASSERT_TRUE(Config.Dispatch.resource == nil or type(Config.Dispatch.resource) == 'string')
    ASSERT_TRUE(Config.Dispatch.serverEvent == nil or type(Config.Dispatch.serverEvent) == 'string')
end)

TEST('item-required sabotage and repair fail closed when consumption fails', function()
    local sabotageFile = assert(io.open('server/sabotage.lua', 'r'))
    local sabotage = sabotageFile:read('*a')
    sabotageFile:close()

    local repairFile = assert(io.open('server/repair_manager.lua', 'r'))
    local repair = repairFile:read('*a')
    repairFile:close()

    ASSERT_TRUE(sabotage:find('if not removed then', 1, true) ~= nil)
    ASSERT_TRUE(repair:find('hasAllMaterials(repair.source, repair.plan.materials)', 1, true) ~= nil)
    ASSERT_TRUE(repair:find('if not consumed then', 1, true) ~= nil)
end)

TEST('apiquery returns the snapshot to the caller and identifies its source', function()
    local serverFile = assert(io.open('server/debug.lua', 'r'))
    local server = serverFile:read('*a')
    serverFile:close()

    local clientFile = assert(io.open('client/debug.lua', 'r'))
    local client = clientFile:read('*a')
    clientFile:close()

    ASSERT_TRUE(server:find('gnsh%-blackout:client:apiQueryResult') ~= nil)
    ASSERT_TRUE(server:find('API result source=%%s') ~= nil)
    ASSERT_TRUE(client:find("RegisterNetEvent%('gnsh%-blackout:client:apiQueryResult'") ~= nil)
end)
