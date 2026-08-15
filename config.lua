--[[
    config.lua

    Top-level configuration for the City Infrastructure power grid
    framework. Grid/substation/transformer TOPOLOGY lives in
    shared/grids.lua and district AABBs in shared/districts.lua — this
    file only holds tunables and toggles (RULE 7: config-driven, not
    hardcoded).

    Loaded BEFORE shared/constants.lua (see fxmanifest.lua), so nothing
    here may reference `Constants.*` — plain string/number literals only.
]]

Config = {}

-- ── Bridge (spec §55, §56) ──────────────────────────────────────────────
-- 'auto' probes GetResourceState() for known resources at startup and
-- falls back to the standalone adapter if none are running. The UI categories
-- stay explicit so framework-owned native screens cannot replace the resource
-- UI. Set an explicit provider only when an intentional override is needed.
Config.Bridge = {
    framework = 'auto',
    inventory = 'auto',
    target = 'auto',
    notify = 'nui',
    menu = 'nui',
    progress = 'nui',
    skillcheck = 'nui',
    database = 'auto',
}

-- Standalone interaction presentation. External target adapters keep their
-- own target UI; these values only affect the dependency-free fallback.
Config.Interaction = {
    standalonePromptDistance = 2.5,
    standalonePromptHeight = 0.85,
    standalonePromptScale = 0.32,
}

-- ── Debug / logging ──────────────────────────────────────────────────────
Config.Debug = {
    enabled = false,        -- production default; enable explicitly for diagnostics
    adminGroup = 'admin',   -- Bridge.HasPermission() group required for mutating debug commands
    convar = 'gnsh_blackout_debug', -- setr this to true for a controlled test session
}

function Config.IsDebugEnabled()
    local debug = Config.Debug
    if type(debug) ~= 'table' then return false end

    local enabled = debug.enabled == true
    if type(GetConvar) == 'function' and type(debug.convar) == 'string' and debug.convar ~= '' then
        local value = GetConvar(debug.convar, enabled and 'true' or 'false')
        value = string.lower(tostring(value))
        return value == '1' or value == 'true' or value == 'yes' or value == 'on'
    end

    return enabled
end

Config.LogLevel = 'info' -- 'debug' | 'info' | 'warn' | 'error'

-- ── District resolution (spec §29, §59) ─────────────────────────────────
Config.District = {
    pollInterval = 500,     -- ms between GetNameOfZone() checks (movement-gated, see below)
    moveThreshold = 5.0,    -- metres of movement required since last poll before re-checking zone
    stableTime = 350,       -- ms a candidate district must hold before it's committed (hysteresis)
    teleportThreshold = 150.0, -- metres moved in one tick that forces an immediate re-resolve
}

-- One-time development exporter for the admin map's native district layer.
-- It is available only while Config.IsDebugEnabled() is true and the caller
-- passes the normal server-side admin permission check. Runtime gameplay and
-- opening the admin panel never trigger a scan.
Config.DistrictMapExport = {
    enabled = true,
    command = 'districtscan',
    cancelCommand = 'districtscancancel',
    outputPath = 'web/assets/gta-native-districts.json',
    bounds = { minX = -3430, maxX = 3990, minY = -3560, maxY = 7160 },
    cellSize = 10,
    sampleZ = 0.0,
    callsPerFrame = 1200,
    latentBps = 1000000,
    maxPayloadBytes = 8 * 1024 * 1024,
    maxGeometryItems = 1000000,
}

-- ── Zone resolver priority (spec §9, §50) ───────────────────────────────
-- Order in which resolvers are tried. First match wins.
Config.ResolverPriority = { 'custom_zone', 'gta_native' }

-- Custom polygon/radius zones (spec §8, §9). Empty by default — the MVP
-- relies entirely on the GTA native resolver. See shared/zone_resolver.lua
-- for the expected shape of each entry.
-- Example:
-- Config.Zones = {
--     {
--         id = 'example_prison',
--         type = 'polygon',        -- 'polygon' | 'radius'
--         gridId = 'blaine_south',
--         points = { { x = 1, y = 1 }, { x = 1, y = 5 }, { x = 5, y = 5 }, { x = 5, y = 1 } },
--         minZ = 0.0, maxZ = 50.0,
--         priority = 10,
--     },
-- }
Config.Zones = {}

-- Grid a position resolves to when no custom zone AND no known GTA district
-- claims it. `nil` means "treat as powered" (fail-open — an unmapped
-- position should not spuriously report a blackout to an unrelated
-- resource). Set to a real grid id to fail into a specific grid instead.
Config.DefaultGrid = nil

-- ── Power model (spec §16) ───────────────────────────────────────────────
-- Transformer condition at/above which SetState() forces OFFLINE
-- regardless of the transformer's current operational state.
Config.OfflineAtCondition = 'DESTROYED'

-- Power contribution of a DEGRADED transformer toward grid `level`.
Config.DegradedLevel = 0.6

-- Grid `level` below this value is reported as GridStatus.BLACKOUT.
Config.BlackoutThreshold = 0.05

-- ── Incident System (spec §17, §45, Phase 11) ───────────────────────────
-- Resolved/cancelled incidents are kept in memory as a bounded ring
-- buffer (Phase 14 will persist them to SQL instead) — this just stops
-- incidentHistory growing forever on a long-uptime server.
Config.MaxIncidentHistory = 200

-- Optional dispatch bridge (spec §23, Phase 23). The internal
-- `infra:dispatchIncident` event is emitted without any external resource;
-- resource/event are only needed when a concrete dispatch script is wired.
-- No dispatch resource is a valid production configuration.
Config.Dispatch = {
    enabled = true,
    resource = nil,
    serverEvent = nil,
    emitInternalEvent = true,
}

Config.RandomFailure = {
    enabled = false,
    tickSec = 60,
    transformerWeight = 1.0,
    feederWeight = 0.0,
    substationWeight = 0.0,
    maxAutomaticOfflineDistricts = 6,
    cooldownSec = 300,
}

Config.Security = {
    enabled = true,
    txAdmin = true,
    allowCommandAceAdmins = true, -- global FXServer command operators may use infrastructure admin commands
    commandAcePermissions = {
        'command',
        'command.refresh',
        'command.restart',
    },
    maxStringLength = 64,
    rateWindowSec = 10,
    maxEventsPerWindow = 20,
    auditWindowSec = 1,
    maxSessionTtlSec = 60,
}

Config.Metrics = {
    enabled = false,
    sampleIntervalSec = 10,
    maxSamples = 60,
}

-- ── Sabotage System (spec §33, §34, §36, Phase 12) ──────────────────────
-- Only THERMITE and C4 are implemented (spec §33 also lists HACK,
-- PHYSICAL_DAMAGE, CUSTOM — reserved for a later iteration, same pattern
-- as Config.PowerPolicy's WEIGHTED_CAPACITY etc.). Both methods reuse
-- items that already exist in qb-core/shared/items.lua AND
-- ox_inventory/data/items.lua — no new item definitions needed.
Config.Sabotage = {
    enabled = true,
    requireItem = true,            -- spec §36 "Required item exists?" — real items exist now, enforce it
    maxInteractionDistance = 5.0,  -- metres, server-side re-check (spec §36 "Player nearby?")
    minCompletionTime = 3,         -- seconds; also enforced by InteractionManager's anti-speedhack floor
    sessionTimeout = 60,           -- seconds before an unfinished interaction session expires
    cooldownSec = 30,              -- spec §44 SABOTAGE cooldown category, tracked per transformer

    items = {
        thermite = { item = 'thermite', damage = 60, label = 'Termit' },  -- burns through, MAJOR_DAMAGE range
        c4 = { item = 'plastic', damage = 100, label = 'C4' },            -- violent, instant DESTROYED
    },
}

-- ── Repair System (spec §37, §38, §39, §40, Phase 13) ───────────────────
-- `fuse` / `wiring_kit` / `control_module` are now real items — added to
-- [qb]/qb-core/shared/items.lua AND [standalone]/ox_inventory/data/items.lua
-- this phase (no icon assets needed, see those files' header notes).
Config.Repair = {
    enabled = true,
    requireItem = true,              -- items now genuinely exist — enforce it, same as Config.Sabotage
    persistentRepairProgress = true,  -- saves completed stages on active incident (spec §38)
    requiredJob = nil,               -- nil for any player, or string job name (e.g. 'electrician')
    maxWorkers = 1,                  -- spec §40 — one interaction session per transformer at a time
    maxInteractionDistance = 6.0,    -- metres, aligned with transformer world interactionRadius
    stageDurationSec = 3,            -- min seconds per stage (progressBar duration + anti-speedhack floor)
    recoveryDurationSec = 5,         -- delay between last stage completing and the transformer going ONLINE
    stages = {
        'DIAGNOSE',
        'ISOLATE_POWER',
        'OPEN_PANEL',
        'REPLACE_COMPONENTS',
        'REWIRE',
        'INSTALL_FUSE',
        'SYSTEM_TEST',
        'RECONNECT_POWER',
    },
    -- Damage-based stage skipping (spec §37: "Damage seviyesine göre bazı
    -- aşamalar skip edilebilir"). Falls back to the full `stages` list
    -- above for any condition not listed here (RepairManager.GetPlan).
    stagesByCondition = {
        MINOR_DAMAGE = { 'DIAGNOSE', 'INSTALL_FUSE', 'SYSTEM_TEST', 'RECONNECT_POWER' },
        MODERATE_DAMAGE = { 'DIAGNOSE', 'OPEN_PANEL', 'REWIRE', 'INSTALL_FUSE', 'SYSTEM_TEST', 'RECONNECT_POWER' },
        MAJOR_DAMAGE = { 'DIAGNOSE', 'ISOLATE_POWER', 'OPEN_PANEL', 'REPLACE_COMPONENTS', 'REWIRE', 'INSTALL_FUSE', 'SYSTEM_TEST', 'RECONNECT_POWER' },
        CRITICAL_DAMAGE = { 'DIAGNOSE', 'ISOLATE_POWER', 'OPEN_PANEL', 'REPLACE_COMPONENTS', 'REWIRE', 'INSTALL_FUSE', 'SYSTEM_TEST', 'RECONNECT_POWER' },
        DESTROYED = { 'DIAGNOSE', 'ISOLATE_POWER', 'OPEN_PANEL', 'REPLACE_COMPONENTS', 'REWIRE', 'INSTALL_FUSE', 'SYSTEM_TEST', 'RECONNECT_POWER' },
    },
    itemsPerCondition = {
        MINOR_DAMAGE = { { item = 'fuse', amount = 1 } },
        MODERATE_DAMAGE = { { item = 'fuse', amount = 2 }, { item = 'wiring_kit', amount = 1 } },
        MAJOR_DAMAGE = { { item = 'fuse', amount = 3 }, { item = 'wiring_kit', amount = 2 }, { item = 'control_module', amount = 1 } },
        CRITICAL_DAMAGE = { { item = 'fuse', amount = 3 }, { item = 'wiring_kit', amount = 3 }, { item = 'control_module', amount = 2 } },
        DESTROYED = { { item = 'fuse', amount = 3 }, { item = 'wiring_kit', amount = 3 }, { item = 'control_module', amount = 2 } },
    },
}

-- ── Topology (spec §17.2, §18.5, Phase 17-18) ───────────────────────────
Config.Topology = {
    -- false (default): registry/topology problems only warn (dev-friendly,
    -- matches how this whole project treats config gaps up to now — see
    -- shared/districts.lua's own "approximate, not verified" AABB stance).
    -- true: Validators.ValidateAll() treats them as hard errors, same
    -- severity as a broken grid->substation reference — for a production
    -- server where a silently-unassigned district is worse than refusing
    -- to start.
    strict = false,
    -- District-level power aggregation policy across the feeders that
    -- supply it (Phase 18). Only 'ANY' is implemented today (powered if
    -- at least one supplying feeder is powered) — reserved names follow
    -- the same "not implemented yet" validator-rejection pattern as
    -- Config.PowerPolicy's WEIGHTED_CAPACITY.
    districtPolicy = 'ANY',
    -- Log a warning (not an error) for a district listed in a grid's
    -- `districts` but not fed by any feeder — Phase 18 falls back to
    -- grid-level power for it (today's Phase 1-16 behavior), this just
    -- makes that fallback visible instead of silent.
    warnUnassignedDistricts = true,
}

-- menuv/menuv.lua ALSO declares a bare global `Config` (its own settings
-- table) and, because '@menuv/menuv.lua' is imported into THIS resource's
-- client_scripts (see fxmanifest.lua), it overwrites this `Config` global
-- the moment it loads — client-side only (menuv isn't imported into
-- server_scripts), which is why this only ever broke on the client (found
-- via live testing, 2026-08-08: bridge/loader.lua's client branch reading
-- `Config.Bridge` as nil right after config.lua had just populated it).
-- Stash a collision-proof reference here so client/restore_config.lua
-- (loaded right after the menuv import, before bridge/loader.lua) can
-- restore it before anything else reads `Config`.
_G.__GnshBlackoutConfig = Config
