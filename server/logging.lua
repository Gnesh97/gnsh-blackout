--[[
    server/logging.lua

    Structured logging (spec §65). One line per event, human-readable but
    grep/parse-friendly. Config.LogLevel gates 'debug' noise in production.

    Log.event() is the primary entry point — it takes one of the
    Constants.LogEvent codes plus a flat data table and prints:
        [gnsh-blackout] EVENT_CODE key=value key2=value2 ...
]]

Log = {}

local LEVELS = { debug = 1, info = 2, warn = 3, error = 4 }
local PREFIX = '^5[gnsh-blackout]^7'

local function currentLevel()
    return LEVELS[Config.LogLevel] or LEVELS.info
end

local function serializeValue(v)
    if type(v) == 'table' then
        -- Shallow, single-line serialization — good enough for log lines;
        -- anything needing deep inspection should use /griddebug instead.
        local parts = {}
        for k, val in pairs(v) do
            parts[#parts + 1] = ('%s=%s'):format(tostring(k), tostring(val))
        end
        return '{' .. table.concat(parts, ',') .. '}'
    end
    return tostring(v)
end

local function serializeData(data)
    if not data then return '' end
    local parts = {}
    for k, v in pairs(data) do
        parts[#parts + 1] = ('%s=%s'):format(k, serializeValue(v))
    end
    table.sort(parts) -- deterministic ordering makes logs diffable
    return table.concat(parts, ' ')
end

-- `code` should be one of Constants.LogEvent.*, but any string is accepted
-- so callers can't hard-crash the server over a logging typo.
function Log.event(code, data)
    if currentLevel() > LEVELS.info then return end
    print(('%s %s %s'):format(PREFIX, tostring(code), serializeData(data)))
end

function Log.debug(msg, data)
    if currentLevel() > LEVELS.debug then return end
    print(('%s ^6[debug]^7 %s %s'):format(PREFIX, tostring(msg), serializeData(data)))
end

function Log.warn(msg, data)
    if currentLevel() > LEVELS.warn then return end
    print(('%s ^3[warn]^7 %s %s'):format(PREFIX, tostring(msg), serializeData(data)))
end

function Log.error(msg, data)
    print(('%s ^1[error]^7 %s %s'):format(PREFIX, tostring(msg), serializeData(data)))
end
