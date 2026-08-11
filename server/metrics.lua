--[[
    server/metrics.lua

    Phase 27 bounded instrumentation. Metrics are opt-in, in-memory and
    intentionally silent. Hot paths can increment counters without creating
    console spam or unbounded tables.
]]

Metrics = {}

local counters = {}
local samples = {}
local startedAt = os.time()

local function enabled()
    return Config.Metrics and Config.Metrics.enabled == true
end

local function nowMs()
    if type(GetGameTimer) == 'function' then
        local ok, value = pcall(GetGameTimer)
        if ok and type(value) == 'number' then return value end
    end
    return os.clock() * 1000
end

local function appendSample(name, value)
    if not enabled() then return end
    local maxSamples = (Config.Metrics and Config.Metrics.maxSamples) or 60
    samples[name] = samples[name] or {}
    local bucket = samples[name]
    bucket[#bucket + 1] = value
    while #bucket > maxSamples do table.remove(bucket, 1) end
end

function Metrics.Inc(name, amount)
    if not enabled() then return end
    if type(name) ~= 'string' or name == '' then return end
    counters[name] = (counters[name] or 0) + (tonumber(amount) or 1)
end

function Metrics.Observe(name, value)
    if type(name) ~= 'string' or type(value) ~= 'number' then return end
    appendSample(name, value)
end

function Metrics.Measure(name, callback)
    if type(callback) ~= 'function' then return nil, 'callback required' end
    local started = nowMs()
    local ok, result, extra = pcall(callback)
    Metrics.Observe(name, nowMs() - started)
    if not ok then return nil, result end
    return result, extra
end

function Metrics.Set(name, value)
    if not enabled() then return end
    if type(name) ~= 'string' then return end
    counters[name] = tonumber(value) or 0
end

function Metrics.Snapshot()
    local result = {
        enabled = enabled(),
        uptimeSec = os.time() - startedAt,
        counters = {},
        samples = {},
        memoryKb = collectgarbage('count'),
    }
    for name, value in pairs(counters) do result.counters[name] = value end
    for name, values in pairs(samples) do
        result.samples[name] = {}
        for index, value in ipairs(values) do result.samples[name][index] = value end
    end
    return result
end

function Metrics.Reset()
    counters = {}
    samples = {}
    startedAt = os.time()
end

