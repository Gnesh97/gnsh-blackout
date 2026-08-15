--[[
    shared/feeders.lua

    Feeder layer for the complete logical topology:
        GRID -> SUBSTATION -> FEEDER -> TRANSFORMER -> DISTRICT

    Each city substation has two independent primary feeders. District lists
    are explicit and intentionally disjoint; a district belongs to one grid
    and one feeder in this release. Physical interaction availability is
    controlled separately by shared/world_placement.lua.
]]

Feeders = {}

-- ── Blaine South ────────────────────────────────────────────────────────
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

-- ── Los Santos Central ─────────────────────────────────────────────────
Feeders['ls_central_feed_a'] = {
    substationId = 'ls_central_substation_01',
    label = 'Los Santos Central Feeder A',
    transformers = { 'ls_central_tr_01' },
    districts = { 'DOWNT', 'LEGSQU', 'PBOX', 'SKID' },
    priority = 1,
    capacity = 1.0,
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
}

Feeders['ls_central_feed_b'] = {
    substationId = 'ls_central_substation_01',
    label = 'Los Santos Central Feeder B',
    transformers = { 'ls_central_tr_02' },
    districts = { 'KOREAT', 'MOVIE', 'MURRI' },
    priority = 2,
    capacity = 1.0,
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
}

-- ── Los Santos South ────────────────────────────────────────────────────
Feeders['ls_south_feed_a'] = {
    substationId = 'ls_south_substation_01',
    label = 'Los Santos South Feeder A',
    transformers = { 'ls_south_tr_01' },
    districts = { 'CHAMH', 'DAVIS', 'RANCHO', 'STRAW' },
    priority = 1,
    capacity = 1.0,
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
}

Feeders['ls_south_feed_b'] = {
    substationId = 'ls_south_substation_01',
    label = 'Los Santos South Feeder B',
    transformers = { 'ls_south_tr_02' },
    districts = { 'BANNING', 'STAD', 'ZQ_UAR' },
    priority = 2,
    capacity = 1.0,
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
}

-- ── Los Santos West ─────────────────────────────────────────────────────
Feeders['ls_west_feed_a'] = {
    substationId = 'ls_west_substation_01',
    label = 'Los Santos West Feeder A',
    transformers = { 'ls_west_tr_01' },
    districts = { 'BEACH', 'DELBE', 'DELPE', 'VCANA', 'VESP' },
    priority = 1,
    capacity = 1.0,
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
}

Feeders['ls_west_feed_b'] = {
    substationId = 'ls_west_substation_01',
    label = 'Los Santos West Feeder B',
    transformers = { 'ls_west_tr_02' },
    districts = { 'GOLF', 'LOSPUER', 'PBLUFF', 'RGLEN', 'RICHM', 'ROCKF' },
    priority = 2,
    capacity = 1.0,
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
}

-- ── Los Santos Vinewood ─────────────────────────────────────────────────
Feeders['ls_vinewood_feed_a'] = {
    substationId = 'ls_vinewood_substation_01',
    label = 'Los Santos Vinewood Feeder A',
    transformers = { 'ls_vinewood_tr_01' },
    districts = { 'CHIL', 'DTVINE', 'HAWICK', 'VINE', 'WVINE' },
    priority = 1,
    capacity = 1.0,
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
}

Feeders['ls_vinewood_feed_b'] = {
    substationId = 'ls_vinewood_substation_01',
    label = 'Los Santos Vinewood Feeder B',
    transformers = { 'ls_vinewood_tr_02' },
    districts = { 'BURTON', 'HORS', 'MIRR', 'MORN', 'RTRAK' },
    priority = 2,
    capacity = 1.0,
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
}

-- ── Los Santos East / Industrial ───────────────────────────────────────
Feeders['ls_east_feed_a'] = {
    substationId = 'ls_east_substation_01',
    label = 'Los Santos East Feeder A',
    transformers = { 'ls_east_tr_01' },
    districts = { 'AIRP', 'ELYSIAN', 'TERMINA', 'ZP_ORT' },
    priority = 1,
    capacity = 1.0,
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
}

Feeders['ls_east_feed_b'] = {
    substationId = 'ls_east_substation_01',
    label = 'Los Santos East Industrial Feeder B',
    transformers = { 'ls_east_tr_02' },
    districts = { 'CYPRE', 'EBURO', 'LMESA', 'NOOSE', 'TEXTI' },
    priority = 2,
    capacity = 1.0,
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
}

-- ── Los Santos North / Hills ───────────────────────────────────────────
Feeders['ls_north_feed_a'] = {
    substationId = 'ls_north_substation_01',
    label = 'Los Santos North Feeder A',
    transformers = { 'ls_north_tr_01' },
    districts = { 'ALTA', 'CHU', 'EAST_V', 'GALLI', 'OBSERV' },
    priority = 1,
    capacity = 1.0,
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
}

Feeders['ls_north_feed_b'] = {
    substationId = 'ls_north_substation_01',
    label = 'Los Santos North Feeder B',
    transformers = { 'ls_north_tr_02' },
    districts = { 'BHAMCA', 'GREATC', 'NCHU', 'TONGVAH', 'TONGVAV' },
    priority = 2,
    capacity = 1.0,
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
}

-- ── Los Santos South Extension ─────────────────────────────────────────
Feeders['ls_south_extension_feed_a'] = {
    substationId = 'ls_south_extension_substation_01',
    label = 'Los Santos South Extension Feeder A',
    transformers = { 'ls_south_extension_tr_01' },
    districts = { 'DELSOL' },
    priority = 1,
    capacity = 1.0,
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
}

Feeders['ls_south_extension_feed_b'] = {
    substationId = 'ls_south_extension_substation_01',
    label = 'Los Santos South Extension Feeder B',
    transformers = { 'ls_south_extension_tr_02' },
    districts = { 'PALHIGH' },
    priority = 2,
    capacity = 1.0,
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
}

-- ── Blaine North ────────────────────────────────────────────────────────
Feeders['blaine_north_feed_a'] = {
    substationId = 'blaine_north_substation_01',
    label = 'Blaine North Feeder A',
    transformers = { 'blaine_north_tr_01' },
    districts = {
        'BAYTRE', 'BANHAMC', 'BRADP', 'BRADT', 'CALAFB', 'CANNY', 'CCREAK',
        'ELGORL', 'GALFISH', 'GRAPES',
    },
    priority = 1,
    capacity = 1.0,
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
}

Feeders['blaine_north_feed_b'] = {
    substationId = 'blaine_north_substation_01',
    label = 'Blaine North Feeder B',
    transformers = { 'blaine_north_tr_02' },
    districts = { 'MTCHIL', 'MTGORDO', 'MTJOSE', 'PALCOV', 'PALETO', 'PALFOR', 'PROCOB', 'SANCHIA', 'TATAMO' },
    priority = 2,
    capacity = 1.0,
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
}

-- ── Blaine Central / Reservoir ──────────────────────────────────────────
Feeders['blaine_central_feed_a'] = {
    substationId = 'blaine_central_substation_01',
    label = 'Blaine Central Feeder A',
    transformers = { 'blaine_central_tr_01' },
    districts = { 'ALAMO', 'HARMOSUB', 'LACT', 'LAGO' },
    priority = 1,
    capacity = 1.0,
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
}

Feeders['blaine_central_feed_b'] = {
    substationId = 'blaine_central_substation_01',
    label = 'Blaine Central Feeder B',
    transformers = { 'blaine_central_tr_02' },
    districts = { 'SLAB', 'WINDF', 'ZANCUDO' },
    priority = 2,
    capacity = 1.0,
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
}

-- ── Restricted / Special Infrastructure ─────────────────────────────────
Feeders['restricted_feed_a'] = {
    substationId = 'restricted_substation_01',
    label = 'Restricted Infrastructure Feeder A',
    transformers = { 'restricted_tr_01' },
    districts = { 'ARMYB', 'CMSW', 'HUMLAB' },
    priority = 1,
    capacity = 1.0,
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
}

Feeders['restricted_feed_b'] = {
    substationId = 'restricted_substation_01',
    label = 'Restricted Infrastructure Feeder B',
    transformers = { 'restricted_tr_02' },
    districts = { 'JAIL', 'LDAM', 'PALMPOW' },
    priority = 2,
    capacity = 1.0,
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
}

Utils.FreezeShape(Feeders)
