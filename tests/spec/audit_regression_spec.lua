-- Regression coverage for the MP_TEST_CODE_AUDIT findings.

TEST('replication init advances above revisions already published in StateBags', function()
    local previousGlobalState = GlobalState
    local previousTransformerManager = TransformerManager
    local previousFeederManager = FeederManager
    local previousFailureManager = FailureManager
    local previousReplication = Replication

    local ok, err = pcall(function()
        GlobalState = {
            [Constants.StateKey.DISTRICT .. 'SANDY'] = { revision = 41 },
        }
        TransformerManager = {
            GetState = function()
                return { state = Constants.TransformerState.ONLINE, condition = Constants.Condition.HEALTHY }
            end,
        }
        FeederManager = {
            GetState = function(feederId)
                local feeder = Feeders[feederId]
                return {
                    feederId = feederId,
                    substationId = feeder.substationId,
                    powered = true,
                    level = 1.0,
                    status = Constants.GridStatus.ONLINE,
                    forcedOffline = false,
                }
            end,
        }
        FailureManager = nil
        Replication = nil
        dofile('server/replication.lua')

        Replication.Init()
        local firstRevision = GlobalState[Constants.StateKey.DISTRICT .. 'SANDY'].revision
        ASSERT_EQ(firstRevision, 42)

        Replication.Init()
        local secondRevision = GlobalState[Constants.StateKey.DISTRICT .. 'SANDY'].revision
        ASSERT_TRUE(secondRevision > firstRevision)
    end)

    GlobalState = previousGlobalState
    TransformerManager = previousTransformerManager
    FeederManager = previousFeederManager
    FailureManager = previousFailureManager
    Replication = previousReplication
    if not ok then error(err, 0) end
end)

TEST('restored incident severity is numeric and comparable with new incidents', function()
    local previousIncidentManager = IncidentManager
    local ok, err = pcall(function()
        IncidentManager = nil
        dofile('server/incident_manager.lua')
        IncidentManager.Init()

        ASSERT_TRUE(IncidentManager.RestoreIncident({
            incidentId = 'INC-000901',
            targetType = Constants.ComponentType.TRANSFORMER,
            targetId = 'sandy_tr_01',
            gridId = 'blaine_south',
            severity = '100',
            startedAt = 10,
            status = Constants.IncidentStatus.ACTIVE,
        }))
        ASSERT_TRUE(IncidentManager.RestoreIncident({
            incidentId = 'INC-000902',
            targetType = Constants.ComponentType.TRANSFORMER,
            targetId = 'blaine_south_tr_02',
            gridId = 'blaine_south',
            severity = 50,
            startedAt = 20,
            status = Constants.IncidentStatus.ACTIVE,
        }))

        local incident = IncidentManager.GetActiveIncidentForGrid('blaine_south')
        ASSERT_TRUE(incident ~= nil)
        ASSERT_EQ(type(incident.severity), 'number')
        ASSERT_EQ(incident.severity, 100)
    end)

    IncidentManager = previousIncidentManager
    if not ok then error(err, 0) end
end)

TEST('repair refunds materials when recovery state transition fails', function()
    local previous = {
        Bridge = Bridge,
        Security = Security,
        TransformerManager = TransformerManager,
        Transformers = Transformers,
        InfrastructureWorld = InfrastructureWorld,
        IncidentManager = IncidentManager,
        InteractionManager = InteractionManager,
        RepairManager = RepairManager,
        RegisterNetEvent = RegisterNetEvent,
        AddEventHandler = AddEventHandler,
        TriggerClientEvent = TriggerClientEvent,
        GetPlayerPed = GetPlayerPed,
        GetEntityCoords = GetEntityCoords,
        SetTimeout = SetTimeout,
        Log = Log,
        Metrics = Metrics,
    }
    local previousRepair = Config.Repair
    local currentState = Constants.TransformerState.OFFLINE
    local removed = 0
    local added = 0
    local damageCalls = 0

    local function nearPoint(x, y, z)
        return setmetatable({ x = x, y = y, z = z }, {
            __sub = function(a, b)
                return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, {
                    __len = function() return 0 end,
                })
            end,
        })
    end

    local ok, err = pcall(function()
        Config.Repair = {
            enabled = true,
            requireItem = true,
            requiredJob = nil,
            stages = {},
            stagesByCondition = nil,
            itemsPerCondition = { DESTROYED = { { item = 'repair_kit', amount = 1 } } },
            stageDurationSec = 1,
            recoveryDurationSec = 1,
            persistentRepairProgress = false,
            maxInteractionDistance = 6.0,
        }
        Bridge = {
            HasItem = function() return true end,
            RemoveItem = function() removed = removed + 1; return true end,
            AddItem = function() added = added + 1; return true end,
            Notify = function() end,
        }
        Security = {
            ValidateTarget = function(_, targetId) return true, Constants.ComponentType.TRANSFORMER, targetId end,
            GetTargetRevision = function() return 1 end,
        }
        TransformerManager = {
            GetState = function()
                return { state = currentState, damage = 100, condition = Constants.Condition.DESTROYED, revision = 1 }
            end,
            SetState = function(_, state)
                if state == Constants.TransformerState.REPAIRING then
                    currentState = state
                    return true
                end
                if state == Constants.TransformerState.RECOVERING then
                    return false, 'forced test failure'
                end
                currentState = state
                return true
            end,
            SetDamage = function()
                damageCalls = damageCalls + 1
                return true
            end,
        }
        Transformers = { blaine_south_tr_02 = {} }
        InfrastructureWorld = {
            blaine_south_tr_02 = {
                enabled = true,
                coords = vector3(1975.0, 3745.0, 32.2),
            },
        }
        IncidentManager = {
            GetActiveIncidentForTransformer = function() return nil end,
            UpdateStatus = function() return true end,
        }
        InteractionManager = {}
        RegisterNetEvent = function() end
        AddEventHandler = function() end
        TriggerClientEvent = function() end
        GetPlayerPed = function() return 1 end
        GetEntityCoords = function() return nearPoint(1975.0, 3745.0, 32.2) end
        SetTimeout = function() end
        Log = { event = function() end, warn = function() end }
        Metrics = nil
        RepairManager = nil
        dofile('server/repair_manager.lua')

        local started = RepairManager.StartRepair(1, 'blaine_south_tr_02')
        ASSERT_TRUE(started)
        ASSERT_EQ(removed, 1)
        ASSERT_EQ(added, 1)
        ASSERT_EQ(damageCalls, 0)
        ASSERT_EQ(currentState, Constants.TransformerState.OFFLINE)
    end)

    Config.Repair = previousRepair
    for key, value in pairs(previous) do _G[key] = value end
    if not ok then error(err, 0) end
end)

TEST('failed sabotage result consumes item but does not mutate target', function()
    local previous = {
        Bridge = Bridge,
        Security = Security,
        TransformerManager = TransformerManager,
        InteractionManager = InteractionManager,
        Sabotage = Sabotage,
        RegisterNetEvent = RegisterNetEvent,
        AddEventHandler = AddEventHandler,
        TriggerClientEvent = TriggerClientEvent,
        SetTimeout = SetTimeout,
        GetPlayerPed = GetPlayerPed,
        GetEntityCoords = GetEntityCoords,
        source = source,
        Log = Log,
        Metrics = Metrics,
    }
    local previousConfig = Config.Sabotage
    local handlers = {}
    local removeCalls = 0
    local damageCalls = 0
    local sessionStarts = 0
    local cancelCalls = 0
    local rejectRevision = false

    local ok, err = pcall(function()
        Config.Sabotage = {
            enabled = true,
            requireItem = true,
            maxInteractionDistance = 5.0,
            minCompletionTime = 0,
            sessionTimeout = 60,
            cooldownSec = 60,
            items = { c4 = { item = 'plastic', damage = 100, label = 'C4' } },
        }
        Bridge = {
            HasItem = function() return true end,
            RemoveItem = function() removeCalls = removeCalls + 1; return true end,
            Notify = function() end,
        }
        Security = {
            AllowEvent = function() return true end,
            ValidateSource = function() return true end,
            ValidateTarget = function(_, targetId) return true, Constants.ComponentType.TRANSFORMER, targetId end,
            ValidateString = function(value) return true, value end,
            ValidateSession = function(_, sessionId)
                return true, { targetId = 'sandy_tr_01', targetRevision = 1, action = 'c4', sessionId = sessionId }
            end,
            ValidateRevision = function() return not rejectRevision end,
            GetTargetRevision = function() return 1 end,
            ValidateDistance = function() return true end,
        }
        TransformerManager = {
            GetState = function()
                return { state = Constants.TransformerState.ONLINE, condition = Constants.Condition.HEALTHY, damage = 0 }
            end,
            SetDamage = function() damageCalls = damageCalls + 1; return true end,
        }
        InteractionManager = {
            StartSession = function()
                sessionStarts = sessionStarts + 1
                return 'sabotage-session-' .. tostring(sessionStarts)
            end,
            CancelSession = function()
                cancelCalls = cancelCalls + 1
            end,
            ValidateSessionComplete = function(_, sessionId)
                return true, { targetId = 'sandy_tr_01', action = 'c4', sessionId = sessionId }
            end,
        }
        Transformers = { sandy_tr_01 = {} }
        InfrastructureWorld = { sandy_tr_01 = { enabled = true, coords = vector3(0, 0, 0) } }
        RegisterNetEvent = function(name, handler) handlers[name] = handler end
        AddEventHandler = function() end
        TriggerClientEvent = function() end
        SetTimeout = function() end
        GetPlayerPed = function() return 1 end
        GetEntityCoords = function() return vector3(0, 0, 0) end
        Log = { event = function() end }
        Metrics = nil
        Sabotage = nil
        dofile('server/sabotage.lua')

        source = 1
        handlers['infra:requestSabotage']('sandy_tr_01', 'c4')
        handlers['infra:submitSabotageResult']('sabotage-session-1', false)
        handlers['infra:requestSabotage']('sandy_tr_01', 'c4')
        rejectRevision = true
        handlers['infra:submitSabotageResult']('sabotage-session-2', true)
        ASSERT_EQ(cancelCalls, 1)
        rejectRevision = false
        handlers['infra:requestSabotage']('sandy_tr_01', 'c4')

        ASSERT_EQ(removeCalls, 1)
        ASSERT_EQ(damageCalls, 0)
        ASSERT_EQ(sessionStarts, 3)
    end)

    Config.Sabotage = previousConfig
    for key, value in pairs(previous) do _G[key] = value end
    if not ok then error(err, 0) end
end)

TEST('repair refunds only while recovery still owns the target', function()
    local previous = {
        Bridge = Bridge,
        Security = Security,
        TransformerManager = TransformerManager,
        Transformers = Transformers,
        InfrastructureWorld = InfrastructureWorld,
        IncidentManager = IncidentManager,
        InteractionManager = InteractionManager,
        RepairManager = RepairManager,
        RegisterNetEvent = RegisterNetEvent,
        AddEventHandler = AddEventHandler,
        TriggerClientEvent = TriggerClientEvent,
        GetPlayerPed = GetPlayerPed,
        GetEntityCoords = GetEntityCoords,
        SetTimeout = SetTimeout,
        Log = Log,
        Metrics = Metrics,
    }
    local previousRepair = Config.Repair
    local currentState = Constants.TransformerState.OFFLINE
    local currentDamage = 100
    local removed = 0
    local added = 0
    local recoveryCallback

    local function nearPoint(x, y, z)
        return setmetatable({ x = x, y = y, z = z }, {
            __sub = function(a, b)
                return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, {
                    __len = function() return 0 end,
                })
            end,
        })
    end

    local ok, err = pcall(function()
        Config.Repair = {
            enabled = true,
            requireItem = true,
            requiredJob = nil,
            stages = {},
            stagesByCondition = nil,
            itemsPerCondition = { DESTROYED = { { item = 'repair_kit', amount = 1 } } },
            stageDurationSec = 1,
            recoveryDurationSec = 1,
            persistentRepairProgress = false,
            maxInteractionDistance = 6.0,
        }
        Bridge = {
            HasItem = function() return true end,
            RemoveItem = function() removed = removed + 1; return true end,
            AddItem = function() added = added + 1; return true end,
            Notify = function() end,
        }
        Security = {
            ValidateTarget = function(_, targetId) return true, Constants.ComponentType.TRANSFORMER, targetId end,
            GetTargetRevision = function() return 1 end,
        }
        TransformerManager = {
            GetState = function()
                return {
                    state = currentState,
                    damage = currentDamage,
                    condition = currentDamage == 100 and Constants.Condition.DESTROYED or Constants.Condition.HEALTHY,
                    revision = 1,
                }
            end,
            SetState = function(_, state)
                if state == Constants.TransformerState.ONLINE then
                    return false, 'forced recovery failure'
                end
                currentState = state
                return true
            end,
            SetDamage = function(_, damage)
                currentDamage = damage
                return true
            end,
        }
        Transformers = { blaine_south_tr_02 = {} }
        InfrastructureWorld = {
            blaine_south_tr_02 = {
                enabled = true,
                coords = vector3(1975.0, 3745.0, 32.2),
            },
        }
        IncidentManager = {
            GetActiveIncidentForTransformer = function() return nil end,
            UpdateStatus = function() return true end,
        }
        InteractionManager = {}
        RegisterNetEvent = function() end
        AddEventHandler = function() end
        TriggerClientEvent = function() end
        GetPlayerPed = function() return 1 end
        GetEntityCoords = function() return nearPoint(1975.0, 3745.0, 32.2) end
        SetTimeout = function(_, callback) recoveryCallback = callback end
        Log = { event = function() end, warn = function() end }
        Metrics = nil
        RepairManager = nil
        dofile('server/repair_manager.lua')

        local started = RepairManager.StartRepair(1, 'blaine_south_tr_02')
        ASSERT_TRUE(started)
        ASSERT_EQ(removed, 1)
        ASSERT_EQ(currentState, Constants.TransformerState.RECOVERING)
        ASSERT_EQ(currentDamage, 0)
        ASSERT_TRUE(recoveryCallback ~= nil)

        recoveryCallback()

        ASSERT_EQ(currentState, Constants.TransformerState.OFFLINE)
        ASSERT_EQ(currentDamage, 100)
        ASSERT_EQ(added, 1)

        -- If another mutation moves the transformer out of RECOVERING
        -- during the recovery window, the failed repair must not refund.
        added = 0
        currentState = Constants.TransformerState.OFFLINE
        currentDamage = 100
        recoveryCallback = nil

        local restarted = RepairManager.StartRepair(1, 'blaine_south_tr_02')
        ASSERT_TRUE(restarted)
        ASSERT_EQ(currentState, Constants.TransformerState.RECOVERING)
        ASSERT_EQ(currentDamage, 0)
        ASSERT_TRUE(recoveryCallback ~= nil)

        currentState = Constants.TransformerState.OFFLINE
        currentDamage = 100
        recoveryCallback()

        ASSERT_EQ(currentState, Constants.TransformerState.OFFLINE)
        ASSERT_EQ(currentDamage, 100)
        ASSERT_EQ(added, 0)
    end)

    Config.Repair = previousRepair
    for key, value in pairs(previous) do _G[key] = value end
    if not ok then error(err, 0) end
end)

TEST('visual profile with native blackout disabled removes a transferred native effect', function()
    local previous = {
        AddEventHandler = AddEventHandler,
        VisualProfiles = VisualProfiles,
        VisualOwnership = VisualOwnership,
        Transition = Transition,
        VisualHybrid = VisualHybrid,
        NativeBlackout = NativeBlackout,
        ClientState = ClientState,
        VisualManager = VisualManager,
        Metrics = Metrics,
    }
    local stateHandler
    local heldOwner
    local nativeApplied = false
    local forceSyncCalls = {}

    local ok, err = pcall(function()
        AddEventHandler = function(name, handler)
            if name == 'infra:powerStateChanged' then stateHandler = handler end
        end
        VisualProfiles = {
            Resolve = function(districtId)
                if districtId == 'OLD' then
                    return 'old', { mode = Constants.VisualMode.NATIVE_CLIENT_GATE, nativeBlackout = { enabled = true } }
                end
                return 'native_disabled', { mode = Constants.VisualMode.NATIVE_CLIENT_GATE, nativeBlackout = { enabled = false } }
            end,
        }
        VisualOwnership = {
            Acquire = function(_, owner)
                if heldOwner then return false end
                heldOwner = owner
                return true
            end,
            Release = function(_, owner)
                if heldOwner ~= owner then return false end
                heldOwner = nil
                return true
            end,
        }
        Transition = {
            Cancel = function() end,
            ForceSync = function(enabled)
                nativeApplied = enabled
                forceSyncCalls[#forceSyncCalls + 1] = enabled
            end,
            PlayBlackout = function() end,
            PlayRecovery = function() end,
        }
        VisualHybrid = { Apply = function() end }
        NativeBlackout = {
            IsApplied = function() return nativeApplied end,
            Reset = function() nativeApplied = false end,
        }
        ClientState = {
            ActiveProfiles = {},
            AppliedNativeBlackout = false,
        }
        VisualManager = nil
        Metrics = nil
        dofile('client/visual/manager.lua')

        ASSERT_TRUE(stateHandler ~= nil)
        stateHandler({ districtId = 'OLD', gridId = 'grid_a', powered = false, instant = true })
        ASSERT_TRUE(nativeApplied)
        stateHandler({ districtId = 'NEW', gridId = 'grid_a', powered = false, instant = true })

        ASSERT_EQ(#forceSyncCalls, 2)
        ASSERT_TRUE(forceSyncCalls[1])
        ASSERT_TRUE(not forceSyncCalls[2])
        ASSERT_TRUE(not nativeApplied)
        ASSERT_EQ(heldOwner, nil)
    end)

    for key, value in pairs(previous) do _G[key] = value end
    if not ok then error(err, 0) end
end)
