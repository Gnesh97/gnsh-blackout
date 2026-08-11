--[[
    client/metrics.lua

    Phase 27 client-side samples. Sampling is opt-in and bounded; it never
    changes visual or logical power state.
]]

Metrics = Metrics or {}

local started = false
local counters = {}
local samples = {}

local function enabled()
    return Config.Metrics and Config.Metrics.enabled == true
end

local function observe(name, value)
    if not enabled() or type(name) ~= 'string' or type(value) ~= 'number' then return end
    local bucket = samples[name] or {}
    bucket[#bucket + 1] = value
    local maxSamples = (Config.Metrics and Config.Metrics.maxSamples) or 60
    while #bucket > maxSamples do table.remove(bucket, 1) end
    samples[name] = bucket
end

function Metrics.Inc(name, amount)
    if not enabled() or type(name) ~= 'string' or name == '' then return end
    counters[name] = (counters[name] or 0) + (tonumber(amount) or 1)
end

function Metrics.Observe(name, value)
    observe(name, value)
end

function Metrics.Snapshot()
    local result = { enabled = enabled(), counters = {}, samples = {} }
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
end

function Metrics.Start()
    if started or not Config.Metrics or not Config.Metrics.enabled then return end
    if type(CreateThread) ~= 'function' then return end
    started = true

    CreateThread(function()
        while started do
            local interval = ((Config.Metrics and Config.Metrics.sampleIntervalSec) or 10) * 1000
            Wait(interval)
            if type(GetFrameTime) == 'function' then
                local ok, frameTime = pcall(GetFrameTime)
                if ok and type(frameTime) == 'number' then
                    Metrics.Observe('client.frameTimeMs', frameTime * 1000)
                end
            end
            if type(collectgarbage) == 'function' then
                Metrics.Observe('client.memoryKb', collectgarbage('count'))
            end
        end
    end)
end

function Metrics.Stop()
    started = false
end
