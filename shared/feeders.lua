--[[
    shared/feeders.lua

    Feeder layer (spec §18.3, Phase 18) — sits between SUBSTATION and
    TRANSFORMER in the topology: GRID -> SUBSTATION -> FEEDER ->
    TRANSFORMER -> DISTRICT. A feeder is why "one transformer failing"
    and "one substation failing" aren't the same size of event (spec
    §18.4): a transformer's failure only affects the feeder(s) it belongs
    to (and whatever districts THOSE feeders serve), not every district
    the whole substation touches.

    Feeder state is never stored — like Substation, it's always DERIVED
    from its transformers' current runtime state (server/feeder_manager.lua
    reuses PowerCalculator.Calculate() against `powerPolicy` below, same
    pure function grid-level power already uses).

    Shape:
        feederId = {
            substationId = <existing Substations key>,
            label = <string>,
            transformers = { <existing Transformers keys> },
            districts = { <existing Districts.ByCode keys> },
            priority = <number, informational for now>,
            capacity = <number, informational for now>,
            powerPolicy = { mode = Constants.PowerPolicy.* },
        }

    MIGRATION NOTE (spec §16.5.4 "existing persistence must not break"):
    `sandy_tr_01` — the ONLY transformer that existed before this phase —
    is wired into `blaine_south_feed_a` below feeding the exact same two
    districts (SANDY, HARMO) it always implicitly powered. Any row already
    saved for it in `infrastructure_transformers` keeps working unchanged;
    nothing about its id, substation, or persisted state moved.

    `blaine_south_tr_02` (new this phase, defined in shared/grids.lua)
    exists specifically so the two-feeder acceptance scenario spec §18.7
    calls for ("bir substation birden fazla feeder besleyebilir") is
    actually testable in-game without inventing a whole second region —
    it shares `sandy_substation_01` with sandy_tr_01, feeds DESRT alone,
    and its own feeder can be sabotaged/repaired completely independently
    of Feeder A.

    `ls_central_*` (new this phase) is intentionally the ONLY other region
    wired up this turn — see CHANGELOG's Phase 18 "Bilinçli
    basitleştirmeler" for why the remaining ~80 registered-but-unassigned
    districts from Phase 17 are NOT all wired into a grid here: spec
    §18.1 itself says the exact district-to-region split is a map/gameplay
    design decision, not something to mass-invent sight-unseen. Proving
    "multiple grids running simultaneously" (§18.7) only needs one more
    region, not all of them.
]]

Feeders = {}

Feeders['blaine_south_feed_a'] = {
    substationId = 'sandy_substation_01',
    label = 'Sandy Shores Feeder A',
    transformers = { 'sandy_tr_01' },
    districts = { 'SANDY', 'HARMO' },
    priority = 1,
    capacity = 1.0,
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
}

Feeders['blaine_south_feed_b'] = {
    substationId = 'sandy_substation_01',
    label = 'Sandy Shores Feeder B',
    transformers = { 'blaine_south_tr_02' },
    districts = { 'DESRT' },
    priority = 2,
    capacity = 1.0,
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
}

Feeders['ls_central_feed_a'] = {
    substationId = 'ls_central_substation_01',
    label = 'Los Santos Central Feeder A',
    transformers = { 'ls_central_tr_01' },
    districts = { 'DOWNT', 'PBOX', 'SKID' },
    priority = 1,
    capacity = 1.0,
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
}

Utils.FreezeShape(Feeders)
