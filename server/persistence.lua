--[[
    server/persistence.lua

    SQL Persistence (spec §45, §46, §47, Phase 14). This is the ONLY
    module that talks to oxmysql — every other module stays synchronous
    and DB-unaware (spec §46: "Her küçük visual/state değişiminde SQL
    write yapılmamalıdır. Runtime cache kullanılmalıdır").

    BUGFIX (live testing, 2026-08-08): the first version of this file
    hand-rolled raw `exports.oxmysql[method](exports.oxmysql, ...)` calls
    to keep oxmysql a soft dependency. Reads (via `exports.oxmysql:query`,
    proper colon syntax) may have worked, but writes silently went
    nowhere — both infrastructure_transformers and infrastructure_incidents
    stayed empty through a full sabotage+restart cycle, meaning the
    "restart resets everything" bug this phase exists to fix was still
    happening, just for a NEW reason (writes never landed) instead of the
    old one (nothing existed to restore). Same root mistake class as the
    MenuV bug: assuming an undocumented cross-resource calling convention
    instead of using the vendor's own tested entry point. Fixed by
    importing '@oxmysql/lib/MySQL.lua' (this resource's official Lua
    wrapper, same pattern as '@ox_lib/init.lua') and using its `MySQL.*`
    API instead of guessing oxmysql's raw export signature. This makes
    oxmysql a real hard `dependency` (fxmanifest.lua) — in practice this
    server can never run without it anyway (qb-core itself requires it).
]]

Persistence = {}

local function available()
    return GetResourceState('oxmysql') == 'started'
end

Persistence.Available = available

-- Incident ids are runtime-generated, but their counter must survive a
-- restart even when every previous incident is already RESOLVED/CANCELLED.
-- Keep this parser deterministic so boot can seed the counter without a
-- schema change.
local function highestIncidentCounter(rows)
    local highest = 0
    for _, row in ipairs(rows or {}) do
        local incidentId = row and (row.incident_id or row.incidentId)
        local number = tonumber(tostring(incidentId or ''):match('(%d+)$'))
        if number and number > highest then
            highest = math.floor(number)
        end
    end
    return highest
end

-- Internal testable contract; this is not a FiveM export.
Persistence.GetHighestIncidentCounter = highestIncidentCounter

-- Loads every persisted transformer row, every still-open incident row, and
-- every parent component override (spec §47: restore runtime state before
-- Replication.Init()).
-- Returns { transformers = {...}, incidents = {...}, overrides = {...} } —
-- empty tables (not nil) if oxmysql is unavailable or the tables are empty,
-- so callers never need a nil-check before iterating.
function Persistence.LoadAll()
    if not available() then
        Log.warn('persistence unavailable at boot (oxmysql not running) — memory-only this session')
        return { transformers = {}, incidents = {}, overrides = {}, incidentCounter = 0 }
    end

    local ok1, transformerRows = pcall(MySQL.query.await, 'SELECT * FROM infrastructure_transformers')
    if not ok1 then
        Log.error(('Persistence.LoadAll (transformers) failed: %s'):format(tostring(transformerRows)))
        transformerRows = {}
    end

    local ok2, incidentRows = pcall(
        MySQL.query.await,
        "SELECT * FROM infrastructure_incidents WHERE status NOT IN ('RESOLVED', 'CANCELLED')"
    )
    if not ok2 then
        Log.error(('Persistence.LoadAll (incidents) failed: %s'):format(tostring(incidentRows)))
        incidentRows = {}
    end

    -- Read ids from the full history, not only active incidents. Otherwise a
    -- clean restart resets the in-memory counter and the next insert can
    -- collide with an old primary key such as INC-000001.
    local ok4, incidentIdRows = pcall(MySQL.query.await, 'SELECT incident_id FROM infrastructure_incidents')
    if not ok4 then
        Log.error(('Persistence.LoadAll (incident ids) failed: %s'):format(tostring(incidentIdRows)))
        incidentIdRows = {}
    end

    local ok3, overrideRows = pcall(MySQL.query.await, 'SELECT * FROM infrastructure_component_overrides')
    if not ok3 then
        Log.error(('Persistence.LoadAll (component overrides) failed: %s'):format(tostring(overrideRows)))
        overrideRows = {}
    end

    local incidents = {}
    for _, row in ipairs(incidentRows or {}) do
        incidents[#incidents + 1] = {
            incidentId = row.incident_id,
            gridId = row.grid_id,
            districts = row.districts and json.decode(row.districts) or {},
            substationId = row.substation_id,
            transformerId = row.transformer_id,
            cause = row.cause,
            severity = row.severity,
            status = row.status,
            startedBy = row.started_by,
            startedAt = row.started_at,
            repairer = row.repaired_by,
            completedAt = row.completed_at,
            metadata = row.metadata and json.decode(row.metadata) or {},
        }
    end

    return {
        transformers = transformerRows or {},
        incidents = incidents,
        overrides = overrideRows or {},
        incidentCounter = highestIncidentCounter(incidentIdRows),
    }
end

-- Upsert — called on every meaningful transformer mutation (state
-- transition, damage change), not on every replication recalc. Bare
-- MySQL.update() call (no callback) is oxmysql's supported
-- fire-and-forget form — see lib/MySQL.lua's safeArgs().
function Persistence.SaveTransformer(rec)
    if not available() then return end
    if Metrics then Metrics.Inc('server.dbWrite.transformer') end
    MySQL.update([[
        INSERT INTO infrastructure_transformers
            (transformer_id, substation_id, state, `condition`, damage, last_failure, last_repair, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            substation_id = VALUES(substation_id),
            state = VALUES(state),
            `condition` = VALUES(`condition`),
            damage = VALUES(damage),
            last_failure = VALUES(last_failure),
            last_repair = VALUES(last_repair),
            updated_at = VALUES(updated_at)
    ]], {
        rec.id, rec.substationId, rec.state, rec.condition, rec.damage,
        rec.lastFailure, rec.lastRepair, rec.updatedAt,
    })
end

-- Insert — called once, at IncidentManager.CreateIncident().
function Persistence.SaveIncident(inc)
    if not available() then return end
    if Metrics then Metrics.Inc('server.dbWrite.incidentInsert') end
    MySQL.insert([[
        INSERT INTO infrastructure_incidents
            (incident_id, grid_id, districts, substation_id, transformer_id, cause, severity, status, started_by, started_at, repaired_by, completed_at, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        inc.incidentId, inc.gridId, json.encode(inc.districts or {}), inc.substationId, inc.transformerId,
        inc.cause, tostring(inc.severity), inc.status, inc.startedBy and tostring(inc.startedBy) or nil,
        inc.startedAt, inc.repairer and tostring(inc.repairer) or nil, inc.completedAt, json.encode(inc.metadata or {}),
    })
end

-- Update — called on every IncidentManager.UpdateStatus() (status change,
-- repair progress metadata change, resolve/cancel).
function Persistence.UpdateIncident(inc)
    if not available() then return end
    if Metrics then Metrics.Inc('server.dbWrite.incidentUpdate') end
    MySQL.update([[
        UPDATE infrastructure_incidents SET
            status = ?, repaired_by = ?, completed_at = ?, metadata = ?
        WHERE incident_id = ?
    ]], {
        inc.status, inc.repairer and tostring(inc.repairer) or nil, inc.completedAt, json.encode(inc.metadata or {}),
        inc.incidentId,
    })
end

function Persistence.SaveOverride(record)
    if not available() then return end
    if Metrics then Metrics.Inc('server.dbWrite.override') end
    MySQL.update([[
        INSERT INTO infrastructure_component_overrides
            (component_type, component_id, state, reason, updated_by, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            state = VALUES(state),
            reason = VALUES(reason),
            updated_by = VALUES(updated_by),
            updated_at = VALUES(updated_at)
    ]], {
        record.componentType, record.componentId, record.state, record.reason,
        record.updatedBy and tostring(record.updatedBy) or nil, record.updatedAt,
    })
end

function Persistence.DeleteOverride(componentType, componentId)
    if not available() then return end
    if Metrics then Metrics.Inc('server.dbWrite.overrideDelete') end
    MySQL.update([[
        DELETE FROM infrastructure_component_overrides
        WHERE component_type = ? AND component_id = ?
    ]], { componentType, componentId })
end
