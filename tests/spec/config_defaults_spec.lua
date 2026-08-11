-- Phase 33 production configuration defaults and controlled debug override.

local previousGetConvar = GetConvar

TEST('production defaults keep debug, metrics and random failure disabled', function()
    ASSERT_FALSE(Config.Debug.enabled)
    ASSERT_FALSE(Config.Metrics.enabled)
    ASSERT_FALSE(Config.RandomFailure.enabled)
    ASSERT_EQ(Config.RandomFailure.tickSec, 60)
    ASSERT_EQ(Config.RandomFailure.cooldownSec, 300)
end)

TEST('debug commands can be explicitly enabled by the runtime convar', function()
    GetConvar = function(name, default)
        if name == Config.Debug.convar then return 'true' end
        return default
    end
    ASSERT_TRUE(Config.IsDebugEnabled())

    GetConvar = function(name, default)
        if name == Config.Debug.convar then return 'false' end
        return default
    end
    ASSERT_FALSE(Config.IsDebugEnabled())
end)

TEST('invalid debug configuration is rejected by boot validation', function()
    local previousGroup = Config.Debug.adminGroup
    Config.Debug.adminGroup = ''
    local ok = Validators.ValidateAll()
    Config.Debug.adminGroup = previousGroup
    ASSERT_FALSE(ok)
end)

GetConvar = previousGetConvar
