--[[
    shared/grids.lua

    Static citywide power topology.

    The registry deliberately separates the logical power domain from the
    physical world registry. Every configured district is assigned to one
    explicit grid and every grid has a substation with multiple feeders. A
    component may set physical = false when no verified in-world placement is
    available yet; shared/world_placement.lua keeps that component logical-only
    instead of inventing a map coordinate or spawning a prop.
]]

Grids = {}
Substations = {}
Transformers = {}

-- ── Blaine County ────────────────────────────────────────────────────────
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
    primary = true,
    capacity = 1.0,
}

-- ── Los Santos Central ─────────────────────────────────────────────────
Grids['ls_central'] = {
    label = 'Los Santos Central Power Grid',
    resolver = Constants.Resolver.GTA_NATIVE,
    districts = { 'DOWNT', 'KOREAT', 'LEGSQU', 'MOVIE', 'MURRI', 'PBOX', 'SKID' },
    substations = { 'ls_central_substation_01' },
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
    visual = { profile = 'ls_central' },
}

Substations['ls_central_substation_01'] = {
    gridId = 'ls_central',
    label = 'Los Santos Central Substation',
    transformers = { 'ls_central_tr_01', 'ls_central_tr_02' },
}

Transformers['ls_central_tr_01'] = {
    substationId = 'ls_central_substation_01',
    label = 'Los Santos Central Transformer 01',
    primary = true,
    capacity = 1.0,
}

Transformers['ls_central_tr_02'] = {
    substationId = 'ls_central_substation_01',
    label = 'Los Santos Central Transformer 02',
    primary = true,
    capacity = 1.0,
    physical = false,
}

-- ── Los Santos South ────────────────────────────────────────────────────
Grids['ls_south'] = {
    label = 'Los Santos South Power Grid',
    resolver = Constants.Resolver.GTA_NATIVE,
    districts = { 'BANNING', 'CHAMH', 'DAVIS', 'RANCHO', 'STAD', 'STRAW', 'ZQ_UAR' },
    substations = { 'ls_south_substation_01' },
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
    visual = { profile = 'ls_central' },
}

Substations['ls_south_substation_01'] = {
    gridId = 'ls_south',
    label = 'Los Santos South Substation',
    transformers = { 'ls_south_tr_01', 'ls_south_tr_02' },
    physical = false,
}

Transformers['ls_south_tr_01'] = {
    substationId = 'ls_south_substation_01',
    label = 'Los Santos South Transformer 01',
    primary = true,
    capacity = 1.0,
    physical = false,
}

Transformers['ls_south_tr_02'] = {
    substationId = 'ls_south_substation_01',
    label = 'Los Santos South Transformer 02',
    primary = true,
    capacity = 1.0,
    physical = false,
}

-- ── Los Santos West ─────────────────────────────────────────────────────
Grids['ls_west'] = {
    label = 'Los Santos West Power Grid',
    resolver = Constants.Resolver.GTA_NATIVE,
    districts = { 'BEACH', 'DELBE', 'DELPE', 'GOLF', 'LOSPUER', 'PBLUFF', 'RGLEN', 'RICHM', 'ROCKF', 'VCANA', 'VESP' },
    substations = { 'ls_west_substation_01' },
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
    visual = { profile = 'ls_central' },
}

Substations['ls_west_substation_01'] = {
    gridId = 'ls_west',
    label = 'Los Santos West Substation',
    transformers = { 'ls_west_tr_01', 'ls_west_tr_02' },
    physical = false,
}

Transformers['ls_west_tr_01'] = {
    substationId = 'ls_west_substation_01',
    label = 'Los Santos West Transformer 01',
    primary = true,
    capacity = 1.0,
    physical = false,
}

Transformers['ls_west_tr_02'] = {
    substationId = 'ls_west_substation_01',
    label = 'Los Santos West Transformer 02',
    primary = true,
    capacity = 1.0,
    physical = false,
}

-- ── Los Santos Vinewood ─────────────────────────────────────────────────
Grids['ls_vinewood'] = {
    label = 'Los Santos Vinewood Power Grid',
    resolver = Constants.Resolver.GTA_NATIVE,
    districts = { 'BURTON', 'CHIL', 'DTVINE', 'HAWICK', 'HORS', 'MIRR', 'MORN', 'RTRAK', 'VINE', 'WVINE' },
    substations = { 'ls_vinewood_substation_01' },
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
    visual = { profile = 'ls_central' },
}

Substations['ls_vinewood_substation_01'] = {
    gridId = 'ls_vinewood',
    label = 'Los Santos Vinewood Substation',
    transformers = { 'ls_vinewood_tr_01', 'ls_vinewood_tr_02' },
    physical = false,
}

Transformers['ls_vinewood_tr_01'] = {
    substationId = 'ls_vinewood_substation_01',
    label = 'Los Santos Vinewood Transformer 01',
    primary = true,
    capacity = 1.0,
    physical = false,
}

Transformers['ls_vinewood_tr_02'] = {
    substationId = 'ls_vinewood_substation_01',
    label = 'Los Santos Vinewood Transformer 02',
    primary = true,
    capacity = 1.0,
    physical = false,
}

-- ── Los Santos East / Industrial ───────────────────────────────────────
Grids['ls_east_industrial'] = {
    label = 'Los Santos East Industrial Power Grid',
    resolver = Constants.Resolver.GTA_NATIVE,
    districts = { 'AIRP', 'CYPRE', 'EBURO', 'ELYSIAN', 'LMESA', 'NOOSE', 'TERMINA', 'TEXTI', 'ZP_ORT' },
    substations = { 'ls_east_substation_01' },
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
    visual = { profile = 'ls_central' },
}

Substations['ls_east_substation_01'] = {
    gridId = 'ls_east_industrial',
    label = 'Los Santos East Industrial Substation',
    transformers = { 'ls_east_tr_01', 'ls_east_tr_02' },
    physical = false,
}

Transformers['ls_east_tr_01'] = {
    substationId = 'ls_east_substation_01',
    label = 'Los Santos East Industrial Transformer 01',
    primary = true,
    capacity = 1.0,
    physical = false,
}

Transformers['ls_east_tr_02'] = {
    substationId = 'ls_east_substation_01',
    label = 'Los Santos East Industrial Transformer 02',
    primary = true,
    capacity = 1.0,
    physical = false,
}

-- ── Los Santos North / Hills ───────────────────────────────────────────
Grids['ls_north'] = {
    label = 'Los Santos North Power Grid',
    resolver = Constants.Resolver.GTA_NATIVE,
    districts = { 'ALTA', 'BHAMCA', 'CHU', 'EAST_V', 'GALLI', 'GREATC', 'NCHU', 'OBSERV', 'TONGVAH', 'TONGVAV' },
    substations = { 'ls_north_substation_01' },
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
    visual = { profile = 'ls_central' },
}

Substations['ls_north_substation_01'] = {
    gridId = 'ls_north',
    label = 'Los Santos North Substation',
    transformers = { 'ls_north_tr_01', 'ls_north_tr_02' },
    physical = false,
}

Transformers['ls_north_tr_01'] = {
    substationId = 'ls_north_substation_01',
    label = 'Los Santos North Transformer 01',
    primary = true,
    capacity = 1.0,
    physical = false,
}

Transformers['ls_north_tr_02'] = {
    substationId = 'ls_north_substation_01',
    label = 'Los Santos North Transformer 02',
    primary = true,
    capacity = 1.0,
    physical = false,
}

-- ── Los Santos South Extension ─────────────────────────────────────────
Grids['ls_south_extension'] = {
    label = 'Los Santos South Extension Power Grid',
    resolver = Constants.Resolver.GTA_NATIVE,
    districts = { 'DELSOL', 'PALHIGH' },
    substations = { 'ls_south_extension_substation_01' },
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
    visual = { profile = 'ls_central' },
}

Substations['ls_south_extension_substation_01'] = {
    gridId = 'ls_south_extension',
    label = 'Los Santos South Extension Substation',
    transformers = { 'ls_south_extension_tr_01', 'ls_south_extension_tr_02' },
    physical = false,
}

Transformers['ls_south_extension_tr_01'] = {
    substationId = 'ls_south_extension_substation_01',
    label = 'Los Santos South Extension Transformer 01',
    primary = true,
    capacity = 1.0,
    physical = false,
}

Transformers['ls_south_extension_tr_02'] = {
    substationId = 'ls_south_extension_substation_01',
    label = 'Los Santos South Extension Transformer 02',
    primary = true,
    capacity = 1.0,
    physical = false,
}

-- ── Blaine North ────────────────────────────────────────────────────────
Grids['blaine_north'] = {
    label = 'Blaine North Power Grid',
    resolver = Constants.Resolver.GTA_NATIVE,
    districts = {
        'BAYTRE', 'BANHAMC', 'BRADP', 'BRADT', 'CALAFB', 'CANNY', 'CCREAK',
        'ELGORL', 'GALFISH', 'GRAPES', 'MTCHIL', 'MTGORDO', 'MTJOSE',
        'PALCOV', 'PALETO', 'PALFOR', 'PROCOB', 'SANCHIA', 'TATAMO',
    },
    substations = { 'blaine_north_substation_01' },
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
    visual = { profile = 'sandy' },
}

Substations['blaine_north_substation_01'] = {
    gridId = 'blaine_north',
    label = 'Blaine North Substation',
    transformers = { 'blaine_north_tr_01', 'blaine_north_tr_02' },
    physical = false,
}

Transformers['blaine_north_tr_01'] = {
    substationId = 'blaine_north_substation_01',
    label = 'Blaine North Transformer 01',
    primary = true,
    capacity = 1.0,
    physical = false,
}

Transformers['blaine_north_tr_02'] = {
    substationId = 'blaine_north_substation_01',
    label = 'Blaine North Transformer 02',
    primary = true,
    capacity = 1.0,
    physical = false,
}

-- ── Blaine Central / Reservoir ──────────────────────────────────────────
Grids['blaine_central'] = {
    label = 'Blaine Central Power Grid',
    resolver = Constants.Resolver.GTA_NATIVE,
    districts = { 'ALAMO', 'HARMOSUB', 'LACT', 'LAGO', 'SLAB', 'WINDF', 'ZANCUDO' },
    substations = { 'blaine_central_substation_01' },
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
    visual = { profile = 'sandy' },
}

Substations['blaine_central_substation_01'] = {
    gridId = 'blaine_central',
    label = 'Blaine Central Substation',
    transformers = { 'blaine_central_tr_01', 'blaine_central_tr_02' },
    physical = false,
}

Transformers['blaine_central_tr_01'] = {
    substationId = 'blaine_central_substation_01',
    label = 'Blaine Central Transformer 01',
    primary = true,
    capacity = 1.0,
    physical = false,
}

Transformers['blaine_central_tr_02'] = {
    substationId = 'blaine_central_substation_01',
    label = 'Blaine Central Transformer 02',
    primary = true,
    capacity = 1.0,
    physical = false,
}

-- ── Restricted / Special Infrastructure ─────────────────────────────────
Grids['restricted_infrastructure'] = {
    label = 'Restricted Infrastructure Power Grid',
    resolver = Constants.Resolver.GTA_NATIVE,
    districts = { 'ARMYB', 'CMSW', 'HUMLAB', 'JAIL', 'LDAM', 'PALMPOW' },
    substations = { 'restricted_substation_01' },
    powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
    visual = { profile = 'ls_central' },
}

Substations['restricted_substation_01'] = {
    gridId = 'restricted_infrastructure',
    label = 'Restricted Infrastructure Substation',
    transformers = { 'restricted_tr_01', 'restricted_tr_02' },
    physical = false,
}

Transformers['restricted_tr_01'] = {
    substationId = 'restricted_substation_01',
    label = 'Restricted Infrastructure Transformer 01',
    primary = true,
    capacity = 1.0,
    physical = false,
}

Transformers['restricted_tr_02'] = {
    substationId = 'restricted_substation_01',
    label = 'Restricted Infrastructure Transformer 02',
    primary = true,
    capacity = 1.0,
    physical = false,
}

Utils.FreezeShape(Grids)
Utils.FreezeShape(Substations)
Utils.FreezeShape(Transformers)

-- shared/districts.lua loads before this file. This is the single point at
-- which the complete static grid registry is available to the district
-- assignment index on both client and server.
Districts.ComputeAssignments(Grids)
