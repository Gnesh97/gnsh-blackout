--[[
    tests/spec/damage_model_spec.lua

    Exhaustive boundary test of Utils.DamageToCondition against the
    thresholds in spec §14: 0 HEALTHY, 1-20 MINOR, 21-50 MODERATE,
    51-80 MAJOR, 81-99 CRITICAL, 100 DESTROYED.
]]

local C = Constants.Condition

TEST('damage 0 -> HEALTHY', function()
    ASSERT_EQ(Utils.DamageToCondition(0), C.HEALTHY)
end)

TEST('damage 1 -> MINOR_DAMAGE (lower boundary)', function()
    ASSERT_EQ(Utils.DamageToCondition(1), C.MINOR_DAMAGE)
end)

TEST('damage 20 -> MINOR_DAMAGE (upper boundary)', function()
    ASSERT_EQ(Utils.DamageToCondition(20), C.MINOR_DAMAGE)
end)

TEST('damage 21 -> MODERATE_DAMAGE (lower boundary)', function()
    ASSERT_EQ(Utils.DamageToCondition(21), C.MODERATE_DAMAGE)
end)

TEST('damage 50 -> MODERATE_DAMAGE (upper boundary)', function()
    ASSERT_EQ(Utils.DamageToCondition(50), C.MODERATE_DAMAGE)
end)

TEST('damage 38 -> MODERATE_DAMAGE (spec §13 example)', function()
    ASSERT_EQ(Utils.DamageToCondition(38), C.MODERATE_DAMAGE)
end)

TEST('damage 51 -> MAJOR_DAMAGE (lower boundary)', function()
    ASSERT_EQ(Utils.DamageToCondition(51), C.MAJOR_DAMAGE)
end)

TEST('damage 80 -> MAJOR_DAMAGE (upper boundary)', function()
    ASSERT_EQ(Utils.DamageToCondition(80), C.MAJOR_DAMAGE)
end)

TEST('damage 81 -> CRITICAL_DAMAGE (lower boundary)', function()
    ASSERT_EQ(Utils.DamageToCondition(81), C.CRITICAL_DAMAGE)
end)

TEST('damage 99 -> CRITICAL_DAMAGE (upper boundary)', function()
    ASSERT_EQ(Utils.DamageToCondition(99), C.CRITICAL_DAMAGE)
end)

TEST('damage 100 -> DESTROYED', function()
    ASSERT_EQ(Utils.DamageToCondition(100), C.DESTROYED)
end)

TEST('damage above 100 clamps to DESTROYED', function()
    ASSERT_EQ(Utils.DamageToCondition(250), C.DESTROYED)
end)

TEST('negative damage clamps to HEALTHY', function()
    ASSERT_EQ(Utils.DamageToCondition(-10), C.HEALTHY)
end)

TEST('nil damage treated as 0 -> HEALTHY', function()
    ASSERT_EQ(Utils.DamageToCondition(nil), C.HEALTHY)
end)

TEST('Utils.Clamp basic behaviour', function()
    ASSERT_EQ(Utils.Clamp(5, 0, 10), 5)
    ASSERT_EQ(Utils.Clamp(-5, 0, 10), 0)
    ASSERT_EQ(Utils.Clamp(15, 0, 10), 10)
end)
