-- Phase 27 bounded metrics tests.

local realMetricsEnabled = Config.Metrics.enabled
local realMaxSamples = Config.Metrics.maxSamples

TEST('metrics are disabled by default and do not collect', function()
    Config.Metrics.enabled = false
    Metrics.Reset()
    Metrics.Inc('test.disabled')
    local snapshot = Metrics.Snapshot()
    ASSERT_EQ(snapshot.counters['test.disabled'], nil)
end)

TEST('metrics collect counters and observations in bounded windows', function()
    Config.Metrics.enabled = true
    Config.Metrics.maxSamples = 2
    Metrics.Reset()
    Metrics.Inc('test.counter', 2)
    Metrics.Observe('test.duration', 1)
    Metrics.Observe('test.duration', 2)
    Metrics.Observe('test.duration', 3)

    local snapshot = Metrics.Snapshot()
    ASSERT_EQ(snapshot.counters['test.counter'], 2)
    ASSERT_EQ(#snapshot.samples['test.duration'], 2)
    ASSERT_EQ(snapshot.samples['test.duration'][1], 2)
    ASSERT_EQ(snapshot.samples['test.duration'][2], 3)
end)

Config.Metrics.enabled = realMetricsEnabled
Config.Metrics.maxSamples = realMaxSamples
Metrics.Reset()
