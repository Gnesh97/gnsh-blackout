--[[
    shared/constants.lua

    Frozen enum tables and structured log event codes for the City
    Infrastructure power grid framework. Spec references: §13, §14, §15,
    §17, §24, §49, §65.

    These tables are loaded once per Lua VM (client and server each get
    their own copy — this is a `shared_script`, not a genuinely shared
    memory space). Nothing in here should ever be mutated at runtime;
    `Utils.FreezeShape` (shared/utilities.lua) is applied at the bottom of
    this file to catch accidental new-key typos early.
]]

Constants = {}

-- Transformer operational state (spec §13). Distinct from Condition below —
-- a transformer can be ONLINE while badly damaged.
Constants.TransformerState = {
    ONLINE = 'ONLINE',
    DEGRADED = 'DEGRADED',
    OFFLINE = 'OFFLINE',
    REPAIRING = 'REPAIRING',
    RECOVERING = 'RECOVERING',
    COOLDOWN = 'COOLDOWN',
}

-- Transformer physical condition (spec §13, §14).
Constants.Condition = {
    HEALTHY = 'HEALTHY',
    MINOR_DAMAGE = 'MINOR_DAMAGE',
    MODERATE_DAMAGE = 'MODERATE_DAMAGE',
    MAJOR_DAMAGE = 'MAJOR_DAMAGE',
    CRITICAL_DAMAGE = 'CRITICAL_DAMAGE',
    DESTROYED = 'DESTROYED',
}

-- Aggregate grid status, derived by the power calculator (spec §16).
Constants.GridStatus = {
    ONLINE = 'ONLINE',
    DEGRADED = 'DEGRADED',
    PARTIAL = 'PARTIAL',
    BLACKOUT = 'BLACKOUT',
    RECOVERING = 'RECOVERING',
}

-- Parent infrastructure failure targets (spec §§21, 30). These are
-- explicit operational overrides, separate from derived GridStatus values.
Constants.ComponentType = {
    GRID = 'grid',
    SUBSTATION = 'substation',
    FEEDER = 'feeder',
    TRANSFORMER = 'transformer', -- internal ancestor lookup only
}

Constants.ComponentState = {
    ONLINE = 'ONLINE',
    OFFLINE = 'OFFLINE',
}

-- Multi-transformer power policy modes (spec §15). Only PRIMARY / ANY / ALL /
-- REQUIRED_COUNT are implemented in Phase 6 — the rest are reserved names so
-- config authors get a clear "not implemented yet" validator error instead
-- of a silent typo.
Constants.PowerPolicy = {
    PRIMARY = 'PRIMARY',
    ANY = 'ANY',
    ALL = 'ALL',
    REQUIRED_COUNT = 'REQUIRED_COUNT',
    WEIGHTED_CAPACITY = 'WEIGHTED_CAPACITY',
    PRIMARY_BACKUP = 'PRIMARY_BACKUP',
    CUSTOM = 'CUSTOM',
}

-- Geographic zone resolvers (spec §4, §8, §9).
Constants.Resolver = {
    GTA_NATIVE = 'gta_native',
    POLYGON = 'polygon',
    RADIUS = 'radius',
}

-- Visual adapter strategies (spec §24). Only NATIVE_CLIENT_GATE ships in
-- Phase 8; the others are reserved for later phases (15-17).
Constants.VisualMode = {
    NONE = 'NONE',
    NATIVE_CLIENT_GATE = 'NATIVE_CLIENT_GATE',
    IPL = 'IPL',
    INTERIOR_ENTITY_SET = 'INTERIOR_ENTITY_SET',
    ENTITY_OVERLAY = 'ENTITY_OVERLAY',
    MODEL_SWAP = 'MODEL_SWAP',
    HYBRID = 'HYBRID',
    CUSTOM = 'CUSTOM',
}

-- Incident cause / status (spec §17). Defined now even though the incident
-- system itself lands in Phase 11, so the enum surface is stable and other
-- modules (logging, debug output) can reference it without churn later.
Constants.IncidentCause = {
    SABOTAGE = 'SABOTAGE',
    RANDOM_FAILURE = 'RANDOM_FAILURE',
    ADMIN = 'ADMIN',
    SCRIPT = 'SCRIPT',
    DEPENDENCY_FAILURE = 'DEPENDENCY_FAILURE',
    OVERLOAD = 'OVERLOAD',
    UNKNOWN = 'UNKNOWN',
}

Constants.IncidentStatus = {
    ACTIVE = 'ACTIVE',
    ACKNOWLEDGED = 'ACKNOWLEDGED',
    REPAIRING = 'REPAIRING',
    RECOVERING = 'RECOVERING',
    RESOLVED = 'RESOLVED',
    CANCELLED = 'CANCELLED',
}

-- Repair stage names (spec §37, Phase 13). Mirrors Config.Repair.stages'
-- string values as a frozen enum so repair_manager.lua and debug output
-- can reference Constants.RepairStage.X instead of typo-prone literals.
Constants.RepairStage = {
    DIAGNOSE = 'DIAGNOSE',
    ISOLATE_POWER = 'ISOLATE_POWER',
    OPEN_PANEL = 'OPEN_PANEL',
    REPLACE_COMPONENTS = 'REPLACE_COMPONENTS',
    REWIRE = 'REWIRE',
    INSTALL_FUSE = 'INSTALL_FUSE',
    SYSTEM_TEST = 'SYSTEM_TEST',
    RECONNECT_POWER = 'RECONNECT_POWER',
}

-- Structured log event codes (spec §65), plus a few framework-internal ones
-- (CONFIG_INVALID, STATE_TRANSITION_REJECTED) needed by the validator and
-- transformer state machine that the spec doesn't enumerate explicitly.
Constants.LogEvent = {
    INTERACTION_CREATED = 'INTERACTION_CREATED',

    SABOTAGE_STARTED = 'SABOTAGE_STARTED',
    SABOTAGE_FAILED = 'SABOTAGE_FAILED',
    SABOTAGE_SUCCESS = 'SABOTAGE_SUCCESS',

    TRANSFORMER_DAMAGED = 'TRANSFORMER_DAMAGED',
    TRANSFORMER_OFFLINE = 'TRANSFORMER_OFFLINE',

    INCIDENT_CREATED = 'INCIDENT_CREATED',

    GRID_POWER_LOST = 'GRID_POWER_LOST',

    VISUAL_APPLIED = 'VISUAL_APPLIED',
    VISUAL_FAILED = 'VISUAL_FAILED',

    REPAIR_STARTED = 'REPAIR_STARTED',
    REPAIR_STAGE_COMPLETE = 'REPAIR_STAGE_COMPLETE',
    REPAIR_FAILED = 'REPAIR_FAILED',

    GRID_RECOVERING = 'GRID_RECOVERING',
    POWER_RESTORED = 'POWER_RESTORED',
    INCIDENT_RESOLVED = 'INCIDENT_RESOLVED',

    -- Framework-internal, not in spec §65 but needed for RULE 4 / RULE 7
    -- enforcement (reject bad config / reject illegal state transitions
    -- loudly instead of silently).
    CONFIG_INVALID = 'CONFIG_INVALID',
    CONFIG_OK = 'CONFIG_OK',
    STATE_TRANSITION_REJECTED = 'STATE_TRANSITION_REJECTED',
    DISTRICT_AUDIT_MISMATCH = 'DISTRICT_AUDIT_MISMATCH',
    RESOURCE_STARTED = 'RESOURCE_STARTED',
    RESOURCE_STOPPED = 'RESOURCE_STOPPED',
    INFRASTRUCTURE_OFFLINE = 'INFRASTRUCTURE_OFFLINE',
    INFRASTRUCTURE_RESTORED = 'INFRASTRUCTURE_RESTORED',
    INFRASTRUCTURE_FAILURE_REJECTED = 'INFRASTRUCTURE_FAILURE_REJECTED',
    SECURITY_REJECTED = 'SECURITY_REJECTED',
    SECURITY_RATE_LIMITED = 'SECURITY_RATE_LIMITED',
    ADMIN_ACTION = 'ADMIN_ACTION',
}

-- Damage → condition boundaries (spec §14).
--   0        -> HEALTHY
--   1-20     -> MINOR_DAMAGE
--   21-50    -> MODERATE_DAMAGE
--   51-80    -> MAJOR_DAMAGE
--   81-99    -> CRITICAL_DAMAGE
--   100      -> DESTROYED
Constants.DamageThresholds = {
    { max = 0, condition = Constants.Condition.HEALTHY },
    { max = 20, condition = Constants.Condition.MINOR_DAMAGE },
    { max = 50, condition = Constants.Condition.MODERATE_DAMAGE },
    { max = 80, condition = Constants.Condition.MAJOR_DAMAGE },
    { max = 99, condition = Constants.Condition.CRITICAL_DAMAGE },
    { max = 100, condition = Constants.Condition.DESTROYED },
}

-- Payload version stamped on every cross-boundary event (spec §49:
-- "Event payloadları versioned ve documented olmalıdır").
Constants.EVENT_VERSION = 1

-- GlobalState key prefixes (spec §19). Centralized so replication.lua and
-- any consumer never hand-roll the string format.
Constants.StateKey = {
    GRID = 'infra:grid:',
    DISTRICT = 'infra:district:',
    TRANSFORMER = 'infra:transformer:',
    FEEDER = 'infra:feeder:', -- Phase 18
}

-- Guard every enum sub-table against accidental new-key typos (see
-- Utils.FreezeShape for exactly what this does and doesn't protect
-- against). Requires shared/utilities.lua to have loaded first — see
-- fxmanifest.lua shared_scripts ordering.
Utils.FreezeShape(Constants.TransformerState)
Utils.FreezeShape(Constants.Condition)
Utils.FreezeShape(Constants.GridStatus)
Utils.FreezeShape(Constants.ComponentType)
Utils.FreezeShape(Constants.ComponentState)
Utils.FreezeShape(Constants.PowerPolicy)
Utils.FreezeShape(Constants.Resolver)
Utils.FreezeShape(Constants.VisualMode)
Utils.FreezeShape(Constants.IncidentCause)
Utils.FreezeShape(Constants.IncidentStatus)
Utils.FreezeShape(Constants.RepairStage)
Utils.FreezeShape(Constants.LogEvent)
Utils.FreezeShape(Constants.StateKey)
