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
