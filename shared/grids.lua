--[[
    shared/grids.lua

    Static power grid topology (spec §11, §12, §18, §93 MVP scope).

    SUBSTATION and TRANSFORMER are intentionally separate tables (spec §12)
    — the data model is shaped for "one substation -> many transformers"
    from day one. Phase 18 actually USES that headroom for the first time:
    `sandy_substation_01` now has two transformers, one per feeder, so the
    §18.7 "bir substation birden fazla feeder besleyebilir" acceptance
    scenario is a real, testable thing instead of just a comment.

    Transformer/substation ids are STATIC STRINGS chosen here, never a
    network id (spec §92 — "Network ID'yi kalıcı transformer ID yapmak"
    is explicitly forbidden). If a transformer ever gets a physical map
    prop in a later phase, the prop is looked up BY this id, not the other
    way around.

    Phase 18 adds a second grid (`ls_central`) purely to prove "multiple
    grids running simultaneously" (spec §18.7) — see shared/feeders.lua's
    header comment for why the other ~80 registered-but-unassigned
    districts from Phase 17 are NOT all wired up in this same pass.
]]

Grids = {}
Substations = {}
Transformers = {}

-- ── Blaine South grid (Sandy PoC, spec §7, §93 — now the first validated
-- district of the citywide framework rather than the whole project scope,
-- see docs/MIGRATION_AUDIT.md) ──────────────────────────────────────────
Grids['blaine_south'] = {
    label = 'Blaine South Power Grid',
    resolver = Constants.Resolver.GTA_NATIVE,
    districts = { 'SANDY', 'HARMO', 'DESRT' },
    substations = { 'sandy_substation_01' },
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
    visual = { profile = 'sandy' },
}

Substations['sandy_substation_01'] = {
    gridId = 'blaine_south',
    label = 'Sandy Shores Substation',
    -- Phase 18: two transformers now, one per feeder (see
    -- shared/feeders.lua). sandy_tr_01 is unchanged from Phase 1 — any
    -- persisted DB row for it keeps working as-is.
    transformers = { 'sandy_tr_01', 'blaine_south_tr_02' },
}

Transformers['sandy_tr_01'] = {
    substationId = 'sandy_substation_01',
    label = 'Sandy Shores Transformer 01',
    primary = true,
    capacity = 1.0,
}

Transformers['blaine_south_tr_02'] = {
    substationId = 'sandy_substation_01',
    label = 'Blaine South Transformer 02 (Feeder B — Grand Senora Desert)',
    primary = true, -- Feeder B's OWN PRIMARY policy requires this, independent of Feeder A's transformer
    capacity = 1.0,
}

-- ── Los Santos Central grid (Phase 18 — second region, proves multi-grid) ──
Grids['ls_central'] = {
    label = 'Los Santos Central Power Grid',
    resolver = Constants.Resolver.GTA_NATIVE,
    districts = { 'DOWNT', 'PBOX', 'SKID' },
    substations = { 'ls_central_substation_01' },
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
    visual = { profile = 'ls_central' },
}

Substations['ls_central_substation_01'] = {
    gridId = 'ls_central',
    label = 'Los Santos Central Substation',
    transformers = { 'ls_central_tr_01' },
}

Transformers['ls_central_tr_01'] = {
    substationId = 'ls_central_substation_01',
    label = 'Los Santos Central Transformer 01',
    primary = true,
    capacity = 1.0,
}

Utils.FreezeShape(Grids)
Utils.FreezeShape(Substations)
Utils.FreezeShape(Transformers)

-- Phase 17: back-fill each district's assignment status/defaultGrid now
-- that Grids is fully defined — shared/districts.lua loads BEFORE this
-- file (see fxmanifest.lua) and can't know grid membership at its own
-- load time, so this is the one place in the whole resource where both
-- tables are guaranteed loaded. Runs on both client and server (shared
-- script) — cheap, one-time, no natives touched.
Districts.ComputeAssignments(Grids)
