local defaultSecurity = Config.Security
local previousBridge = Bridge
local previousIsPlayerAceAllowed = IsPlayerAceAllowed
local previousGetPlayerPing = GetPlayerPing
local previousGetPlayerPed = GetPlayerPed
local previousGetEntityCoords = GetEntityCoords
local previousInteractionManager = InteractionManager
local previousTransformerManager = TransformerManager

GetPlayerPing = function() return 25 end
GetPlayerPed = function() return 1 end
GetEntityCoords = function() return { x = 0, y = 0, z = 0 } end
Bridge = { HasPermission = function() return false end }
IsPlayerAceAllowed = function() return false end

TEST('security validates bounded strings and enums', function()
    local ok = Security.ValidateString('transformer-1', 'targetId')
    ASSERT_TRUE(ok)

    local tooLong = string.rep('x', Config.Security.maxStringLength + 1)
    local tooLongOk = Security.ValidateString(tooLong, 'targetId')
    ASSERT_FALSE(tooLongOk)

    local enumOk = Security.ValidateEnum('ONLINE', { ONLINE = true }, 'state')
    ASSERT_TRUE(enumOk)
    local enumBad = Security.ValidateEnum('INVALID', { ONLINE = true }, 'state')
    ASSERT_FALSE(enumBad)
end)

TEST('security accepts existing targets and rejects fake or cross-grid targets', function()
    local ok, targetType, targetId = Security.ValidateTarget(Constants.ComponentType.TRANSFORMER, 'sandy_tr_01')
    ASSERT_TRUE(ok)
    ASSERT_EQ(targetType, Constants.ComponentType.TRANSFORMER)
    ASSERT_EQ(targetId, 'sandy_tr_01')

    local fakeOk = Security.ValidateTarget(Constants.ComponentType.TRANSFORMER, 'fake_transformer')
    ASSERT_FALSE(fakeOk)
    local crossGridOk = Security.ValidateTarget('not-a-component', 'sandy_tr_01')
    ASSERT_FALSE(crossGridOk)
end)

TEST('security rate limits repeated events', function()
    Security.ResetForTests()
    local first = Security.AllowEvent(1, 'test:event', 2, 10)
    local second = Security.AllowEvent(1, 'test:event', 2, 10)
    local third = Security.AllowEvent(1, 'test:event', 2, 10)
    ASSERT_TRUE(first)
    ASSERT_TRUE(second)
    ASSERT_FALSE(third)
end)

TEST('security validates session owner, action and target', function()
    InteractionManager = {
        GetSession = function(source, sessionId)
            if source ~= 1 or sessionId ~= 'nonce-1' then return nil end
            return {
                source = 1,
                action = 'thermite',
                targetType = Constants.ComponentType.TRANSFORMER,
                targetId = 'sandy_tr_01',
            }
        end,
    }

    local ok, session = Security.ValidateSession(1, 'nonce-1', 'thermite', Constants.ComponentType.TRANSFORMER, 'sandy_tr_01')
    ASSERT_TRUE(ok)
    ASSERT_EQ(session.targetId, 'sandy_tr_01')

    local wrongAction = Security.ValidateSession(1, 'nonce-1', 'c4', Constants.ComponentType.TRANSFORMER, 'sandy_tr_01')
    ASSERT_FALSE(wrongAction)
    local wrongOwner = Security.ValidateSession(2, 'nonce-1', 'thermite', Constants.ComponentType.TRANSFORMER, 'sandy_tr_01')
    ASSERT_FALSE(wrongOwner)
end)

TEST('security rejects stale target revision', function()
    TransformerManager = {
        GetState = function() return { revision = 4 } end,
    }
    ASSERT_TRUE(Security.ValidateRevision(Constants.ComponentType.TRANSFORMER, 'sandy_tr_01', 4))
    ASSERT_FALSE(Security.ValidateRevision(Constants.ComponentType.TRANSFORMER, 'sandy_tr_01', 3))
end)

TEST('security accepts authenticated txAdmin admins without weakening fallback checks', function()
    Security.ResetForTests()
    Bridge.HasPermission = function() return false end

    ASSERT_TRUE(Security.HandleTxAdminAuth({ netid = 1, isAdmin = true }))
    ASSERT_TRUE(Security.IsTxAdminAdmin(1))
    ASSERT_TRUE(Security.RequireAdmin(1))

    ASSERT_TRUE(Security.HandleTxAdminAuth({ netid = 1, isAdmin = false }))
    ASSERT_FALSE(Security.IsTxAdminAdmin(1))
    ASSERT_FALSE(Security.RequireAdmin(1))
end)

TEST('security clears all cached txAdmin admins on forced reauth', function()
    Security.ResetForTests()
    Bridge.HasPermission = function() return false end

    ASSERT_TRUE(Security.HandleTxAdminAuth({ netid = 1, isAdmin = true }))
    ASSERT_TRUE(Security.RequireAdmin(1))
    ASSERT_TRUE(Security.HandleTxAdminAuth({ netid = -1, isAdmin = false }))
    ASSERT_FALSE(Security.RequireAdmin(1))
end)

TEST('security replaces and revokes txAdmin admin snapshots', function()
    Security.ResetForTests()
    Bridge.HasPermission = function() return false end

    ASSERT_TRUE(Security.HandleTxAdminAdminsUpdated({ 1, 2 }))
    ASSERT_TRUE(Security.RequireAdmin(1))
    ASSERT_TRUE(Security.RequireAdmin(2))

    ASSERT_TRUE(Security.HandleTxAdminAdminsUpdated({ 2 }))
    ASSERT_FALSE(Security.RequireAdmin(1))
    ASSERT_TRUE(Security.RequireAdmin(2))
end)

TEST('security denies unauthorized admin action', function()
    Security.ResetForTests()
    Bridge.HasPermission = function() return false end
    local ok = Security.RequireAdmin(1)
    ASSERT_FALSE(ok)
end)

TEST('security accepts operators with global command ACE access', function()
    Security.ResetForTests()
    Bridge.HasPermission = function() return false end
    local previousAllowCommandAceAdmins = Config.Security.allowCommandAceAdmins
    Config.Security.allowCommandAceAdmins = true
    IsPlayerAceAllowed = function(source, permission)
        return source == 1 and permission == 'command'
    end

    local sourceOneAllowed = Security.RequireAdmin(1)
    local sourceTwoAllowed = Security.RequireAdmin(2)
    IsPlayerAceAllowed = function() return false end
    Config.Security.allowCommandAceAdmins = previousAllowCommandAceAdmins

    ASSERT_TRUE(sourceOneAllowed)
    ASSERT_FALSE(sourceTwoAllowed)
end)

TEST('security accepts the specific ACE used by refresh and restart operators', function()
    Security.ResetForTests()
    Bridge.HasPermission = function() return false end
    local previousAllowCommandAceAdmins = Config.Security.allowCommandAceAdmins
    local previousCommandAcePermissions = Config.Security.commandAcePermissions
    Config.Security.allowCommandAceAdmins = true
    Config.Security.commandAcePermissions = { 'command.refresh', 'command.restart' }
    IsPlayerAceAllowed = function(source, permission)
        return source == 1 and permission == 'command.restart'
    end

    local allowed = Security.RequireAdmin(1)

    IsPlayerAceAllowed = function() return false end
    Config.Security.allowCommandAceAdmins = previousAllowCommandAceAdmins
    Config.Security.commandAcePermissions = previousCommandAcePermissions

    ASSERT_TRUE(allowed)
end)

TEST('security can disable global command ACE admin compatibility', function()
    Security.ResetForTests()
    Bridge.HasPermission = function() return false end
    local previousAllowCommandAceAdmins = Config.Security.allowCommandAceAdmins
    Config.Security.allowCommandAceAdmins = false
    IsPlayerAceAllowed = function() return true end

    local allowed = Security.RequireAdmin(1)
    IsPlayerAceAllowed = function() return false end
    Config.Security.allowCommandAceAdmins = previousAllowCommandAceAdmins

    ASSERT_FALSE(allowed)
end)

TEST('security rechecks interaction distance on completion', function()
    ASSERT_TRUE(Security.ValidateDistance(1, { x = 0, y = 0, z = 0 }, 5.0))
    ASSERT_TRUE(Security.ValidateDistance(1, vector3(0, 0, 0), 5.0))
    ASSERT_FALSE(Security.ValidateDistance(1, { x = 100, y = 0, z = 0 }, 5.0))
end)

TEST('invalid security configuration is rejected by boot validation', function()
    local oldMaxStringLength = Config.Security.maxStringLength
    local oldTxAdmin = Config.Security.txAdmin
    local oldAllowCommandAceAdmins = Config.Security.allowCommandAceAdmins
    local oldCommandAcePermissions = Config.Security.commandAcePermissions
    Config.Security.maxStringLength = 0
    Config.Security.txAdmin = 'enabled'
    Config.Security.allowCommandAceAdmins = 'enabled'
    Config.Security.commandAcePermissions = { true }
    local ok = Validators.ValidateAll()
    Config.Security.maxStringLength = oldMaxStringLength
    Config.Security.txAdmin = oldTxAdmin
    Config.Security.allowCommandAceAdmins = oldAllowCommandAceAdmins
    Config.Security.commandAcePermissions = oldCommandAcePermissions
    ASSERT_FALSE(ok)
end)

Config.Security = defaultSecurity
Bridge = previousBridge
IsPlayerAceAllowed = previousIsPlayerAceAllowed
GetPlayerPing = previousGetPlayerPing
GetPlayerPed = previousGetPlayerPed
GetEntityCoords = previousGetEntityCoords
InteractionManager = previousInteractionManager
TransformerManager = previousTransformerManager
Security.ResetForTests()
