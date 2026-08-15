--[[
    server/persistence.lua

    Runtime persistence facade. SQL is reachable only through Bridge.Database;
    gameplay modules never import oxmysql or call vendor exports directly.
    memory adapter keeps the resource functional without restart persistence.
]]

Persistence = {}

local function database()
    return Bridge and Bridge.Database
end

local function available()
    local db = database()
    return db and type(db.Available) == 'function' and db.Available() == true
end

Persistence.Available = available

local function highestIncidentCounter(rows)
    local highest = 0
    for _, row in ipairs(rows or {}) do
        local incidentId = row and (row.incident_id or row.incidentId)
        local number = tonumber(tostring(incidentId or ''):match('(%d+)$'))
        if number and number > highest then highest = math.floor(number) end
    end
    return highest
end

Persistence.GetHighestIncidentCounter = highestIncidentCounter

local function decode(value)
    if type(value) ~= 'string' or type(json) ~= 'table' or type(json.decode) ~= 'function' then return {} end
    local ok, result = pcall(json.decode, value)
    return ok and type(result) == 'table' and result or {}
end

local function query(sql, params, label)
    local db = database()
    if not db or type(db.Query) ~= 'function' then return {} end
    local ok, rows, err = pcall(db.Query, sql, params or {})
    if not ok or rows == nil then
        Log.error(('Persistence.%s failed: %s'):format(label, tostring(err or rows)))
        return {}
    end
    return rows or {}
end

local function write(method, sql, params, metric, label)
    if not available() then return false end
    if Metrics then Metrics.Inc(metric) end
    local db = database()
    local ok, result, err = pcall(db[method], sql, params or {})
    if not ok or result == nil and err then
        Log.error(('Persistence.%s failed: %s'):format(label, tostring(err or result)))
        return false
    end
    return true
end

function Persistence.LoadAll()
    if not available() then
        Log.warn('persistence unavailable at boot - memory-only this session')
        return { transformers = {}, incidents = {}, overrides = {}, incidentCounter = 0 }
    end

    local transformerRows = query('SELECT * FROM infrastructure_transformers', {}, 'LoadAll(transformers)')
    local incidentRows = query("SELECT * FROM infrastructure_incidents WHERE status NOT IN ('RESOLVED', 'CANCELLED')", {}, 'LoadAll(incidents)')
    local incidentIdRows = query('SELECT incident_id FROM infrastructure_incidents', {}, 'LoadAll(incident ids)')
    local overrideRows = query('SELECT * FROM infrastructure_component_overrides', {}, 'LoadAll(overrides)')

    local incidents = {}
    for _, row in ipairs(incidentRows) do
        incidents[#incidents + 1] = {
            incidentId = row.incident_id,
            gridId = row.grid_id,
            districts = decode(row.districts),
            substationId = row.substation_id,
            feederId = row.feeder_id,
            transformerId = row.transformer_id,
            cause = row.cause,
            severity = row.severity,
            status = row.status,
            startedBy = row.started_by,
            startedAt = row.started_at,
            repairer = row.repaired_by,
            completedAt = row.completed_at,
            metadata = decode(row.metadata),
        }
    end

    return {
        transformers = transformerRows,
        incidents = incidents,
        overrides = overrideRows,
        incidentCounter = highestIncidentCounter(incidentIdRows),
    }
end

function Persistence.SaveTransformer(rec)
    return write('Update', [[
        INSERT INTO infrastructure_transformers
            (transformer_id, substation_id, state, `condition`, damage, last_failure, last_repair, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            substation_id = VALUES(substation_id), state = VALUES(state),
            `condition` = VALUES(`condition`), damage = VALUES(damage),
            last_failure = VALUES(last_failure), last_repair = VALUES(last_repair),
            updated_at = VALUES(updated_at)
    ]], {
        rec.id, rec.substationId, rec.state, rec.condition, rec.damage,
        rec.lastFailure, rec.lastRepair, rec.updatedAt,
    }, 'server.dbWrite.transformer', 'SaveTransformer')
end

function Persistence.SaveIncident(inc)
    return write('Insert', [[
        INSERT INTO infrastructure_incidents
            (incident_id, grid_id, districts, substation_id, transformer_id, cause, severity, status, started_by, started_at, repaired_by, completed_at, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        inc.incidentId, inc.gridId, json.encode(inc.districts or {}), inc.substationId,
        inc.transformerId, inc.cause, tostring(inc.severity), inc.status,
        inc.startedBy and tostring(inc.startedBy) or nil, inc.startedAt,
        inc.repairer and tostring(inc.repairer) or nil, inc.completedAt,
        json.encode(inc.metadata or {}),
    }, 'server.dbWrite.incidentInsert', 'SaveIncident')
end

function Persistence.UpdateIncident(inc)
    return write('Update', [[
        UPDATE infrastructure_incidents SET
            status = ?, repaired_by = ?, completed_at = ?, metadata = ?
        WHERE incident_id = ?
    ]], {
        inc.status, inc.repairer and tostring(inc.repairer) or nil, inc.completedAt,
        json.encode(inc.metadata or {}), inc.incidentId,
    }, 'server.dbWrite.incidentUpdate', 'UpdateIncident')
end

function Persistence.SaveOverride(record)
    return write('Update', [[
        INSERT INTO infrastructure_component_overrides
            (component_type, component_id, state, reason, updated_by, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE state = VALUES(state), reason = VALUES(reason),
            updated_by = VALUES(updated_by), updated_at = VALUES(updated_at)
    ]], {
        record.componentType, record.componentId, record.state, record.reason,
        record.updatedBy and tostring(record.updatedBy) or nil, record.updatedAt,
    }, 'server.dbWrite.override', 'SaveOverride')
end

function Persistence.DeleteOverride(componentType, componentId)
    return write('Update', [[
        DELETE FROM infrastructure_component_overrides
        WHERE component_type = ? AND component_id = ?
    ]], { componentType, componentId }, 'server.dbWrite.overrideDelete', 'DeleteOverride')
end
