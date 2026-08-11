-- Phase 31 boot/resync contract tests.

TEST('boot order restores state before grid and district publication', function()
    local position = {}
    for index, name in ipairs(InfrastructureBootOrder) do position[name] = index end

    ASSERT_TRUE(position.persistence < position.grid_calculation)
    ASSERT_TRUE(position.transformer_restore < position.grid_calculation)
    ASSERT_TRUE(position.override_restore < position.grid_calculation)
    ASSERT_TRUE(position.incident_restore < position.district_replication)
    ASSERT_TRUE(position.grid_calculation < position.district_replication)
end)

TEST('scheduler starts after replication in the boot contract', function()
    local position = {}
    for index, name in ipairs(InfrastructureBootOrder) do position[name] = index end
    ASSERT_TRUE(position.district_replication < position.random_failure_scheduler)
end)

TEST('incident counter includes resolved history rows', function()
    local counter = Persistence.GetHighestIncidentCounter({
        { incident_id = 'INC-000001' },
        { incident_id = 'INC-000023' },
        { incident_id = 'legacy-id' },
    })

    ASSERT_EQ(counter, 23)
end)
