--[[
    shared/districts.lua

    GTA native district registry (spec §5, §6, and Phase 17 §17
    "COMPLETE GTA DISTRICT REGISTRY"). Each entry carries an approximate
    axis-aligned bounding box (AABB) for server-side lookup, plus the full
    district model spec §17 asks for: id, label, enabled, category,
    resolver, defaultGrid, visualProfile, metadata.

    WHY TWO REPRESENTATIONS OF THE SAME THING (unchanged since Phase 2):
    `GetNameOfZone(x, y, z)` is a CLIENT-ONLY native — there is no server
    equivalent. But `IsPositionPowered(coords)` (spec §48, §50) must be
    callable from the SERVER, because that's what other resources (ATM,
    doors, CCTV) call. So:

      - client/zone_resolver.lua resolves districts via the native
        GetNameOfZone() — authoritative, always correct.
      - server/zone_resolver.lua resolves districts via the AABB table
        below — an approximation, because the server has no zone native.

    THE AABB VALUES BELOW ARE APPROXIMATE. They were sized generously from
    general knowledge of the GTA V map layout, not extracted from game
    files. They are a reasonable starting point, NOT verified ground
    truth. Before relying on server-side district resolution in
    production, run `/districtaudit` (client) while crossing every
    district border you care about — it compares the client's native
    result against the server's AABB result and logs any mismatch
    (Constants.LogEvent.DISTRICT_AUDIT_MISMATCH); `/districtauditreport`
    (Phase 17) summarizes everything collected so far in one pass instead
    of one console line per crossing. Tighten/correct the boxes below
    until mismatches disappear for your use cases — this is the intended
    purpose of that debug tool, not optional scaffolding.

    Overlapping boxes are resolved by smallest-volume-wins (see
    server/zone_resolver.lua and Utils.AABBVolume), so a small district
    fully nested inside a larger one still resolves correctly.

    HONEST GAP (Phase 17): the original 44 codes (Phase 1-16) plus ~40
    more added this phase get this project to ~84 recognized codes, which
    covers every commonly-referenced GTA V zone this project's author
    could enumerate from general map knowledge — NOT a byte-exact extract
    of the game's own zones.xml (no such file was available to read). If
    `GetNameOfZone` returns a code not in this table, ClientZone.
    ResolveDistrict already logs it once (see that file) so gaps surface
    naturally during play rather than staying silent.
]]

Districts = {}

-- category = 'los_santos' | 'blaine_county' | 'wilderness' | 'water' | 'restricted'
-- enabled defaults to true; set false for conceptual/non-assignable
-- markers (open ocean, the whole-state fallback code) so §17.2's
-- "no topology assignment" warning doesn't fire on entries that were
-- never meant to be claimed by a grid in the first place.
local RAW = {
    -- ── Blaine County (spec §5 examples + neighbours needed for the Sandy grid) ──
    { code = 'SANDY', label = 'Sandy Shores', category = 'blaine_county', min = { 1450, 3300, 20 }, max = { 2450, 3850, 100 } },
    { code = 'HARMO', label = 'Harmony', category = 'blaine_county', min = { 50, 2650, 20 }, max = { 500, 3150, 100 } },
    { code = 'GRAPES', label = 'Grapeseed', category = 'blaine_county', min = { 2100, 4550, 20 }, max = { 2750, 5100, 100 } },
    { code = 'PALETO', label = 'Paleto Bay', category = 'blaine_county', min = { -450, 5900, 10 }, max = { 500, 6650, 100 } },
    { code = 'DESRT', label = 'Grand Senora Desert', category = 'blaine_county', min = { 950, 2350, 20 }, max = { 2900, 4550, 250 } },
    { code = 'ALAMO', label = 'Alamo Sea', category = 'water', min = { 950, 2900, -10 }, max = { 1700, 3600, 30 } },
    { code = 'CANNY', label = 'Raton Canyon', category = 'wilderness', min = { 2550, 3600, 30 }, max = { 3150, 4300, 250 } },
    { code = 'PALFOR', label = 'Paleto Forest', category = 'wilderness', min = { -1400, 5300, 20 }, max = { -350, 6400, 400 } },
    { code = 'MTCHIL', label = 'Mount Chiliad', category = 'wilderness', min = { 300, 5900, 100 }, max = { 950, 6650, 800 } },
    { code = 'ARMYB', label = 'Fort Zancudo', category = 'restricted', min = { -2450, 2900, 0 }, max = { -1650, 3450, 100 } },
    { code = 'CMSW', label = 'Chiliad Mountain State Wilderness', category = 'wilderness', min = { -1900, 3450, 20 }, max = { -900, 4600, 700 } },
    { code = 'PALCOV', label = 'Paleto Cove', category = 'blaine_county', min = { -750, 6300, 0 }, max = { -450, 6700, 40 } },
    { code = 'TATAMO', label = 'Tataviam Mountains', category = 'wilderness', min = { 400, 6300, 100 }, max = { 1200, 7200, 700 } },
    { code = 'SANCHIA', label = 'San Chianski Mountain Range', category = 'wilderness', min = { -1900, 4550, 100 }, max = { -900, 5600, 900 } },
    { code = 'MTGORDO', label = 'Mount Gordo', category = 'wilderness', min = { -500, 6100, 0 }, max = { -100, 6500, 200 } },
    { code = 'MTJOSE', label = 'Mount Josiah', category = 'wilderness', min = { 500, 5000, 100 }, max = { 900, 5450, 500 } },
    { code = 'LACT', label = 'Land Act Reservoir', category = 'blaine_county', min = { 600, 4700, 20 }, max = { 1000, 5000, 60 } },
    { code = 'LAGO', label = 'Lago Zancudo', category = 'water', min = { -2100, 3300, -10 }, max = { -1700, 3600, 20 } },
    { code = 'ZANCUDO', label = 'Zancudo River', category = 'water', min = { -2200, 2600, -10 }, max = { -1900, 3300, 20 } },
    { code = 'CCREAK', label = 'Cassidy Creek', category = 'blaine_county', min = { 2300, 4900, 10 }, max = { 2700, 5300, 60 } },
    { code = 'GALFISH', label = 'Galilee', category = 'blaine_county', min = { 2600, 4950, 10 }, max = { 3100, 5450, 60 } },
    { code = 'PROCOB', label = 'Procopio Beach', category = 'blaine_county', min = { -500, 6700, 0 }, max = { -100, 7100, 30 } },
    { code = 'ELGORL', label = 'El Gordo Lighthouse', category = 'blaine_county', min = { -1750, 7350, 0 }, max = { -1450, 7650, 60 } },
    { code = 'CALAFB', label = 'Calafia Bridge', category = 'blaine_county', min = { -2450, 5100, 0 }, max = { -2100, 5450, 40 } },
    { code = 'BANHAMC', label = 'Banham Canyon', category = 'wilderness', min = { 250, 5250, 50 }, max = { 650, 5700, 300 } },
    { code = 'BRADP', label = 'Braddock Pass', category = 'wilderness', min = { 350, 4600, 50 }, max = { 700, 5000, 300 } },
    { code = 'BRADT', label = 'Braddock Tunnel', category = 'wilderness', min = { 400, 4300, 30 }, max = { 700, 4600, 100 } },
    { code = 'SLAB', label = 'Stab City', category = 'blaine_county', min = { 1400, 2450, 20 }, max = { 1750, 2750, 60 } },
    { code = 'WINDF', label = 'Ron Alternates Wind Farm', category = 'blaine_county', min = { 1600, 2650, 20 }, max = { 2000, 3000, 100 } },
    { code = 'HARMOSUB', label = 'Harmony (Substation Overlap Test Zone)', category = 'blaine_county', min = { 150, 2750, 30 }, max = { 350, 2950, 80 } },

    -- ── Los Santos core (spec §5 examples) ──────────────────────────────
    { code = 'DOWNT', label = 'Downtown', category = 'los_santos', min = { -350, -900, 10 }, max = { 200, -450, 150 } },
    { code = 'SKID', label = 'Mission Row', category = 'los_santos', min = { 300, -1150, 10 }, max = { 550, -800, 100 } },
    { code = 'STRAW', label = 'Strawberry', category = 'los_santos', min = { 50, -1450, 10 }, max = { 400, -1100, 80 } },
    { code = 'DAVIS', label = 'Davis', category = 'los_santos', min = { -50, -1800, 10 }, max = { 350, -1400, 60 } },
    { code = 'RANCHO', label = 'Rancho', category = 'los_santos', min = { -50, -2050, 10 }, max = { 300, -1750, 60 } },
    { code = 'VESP', label = 'Vespucci', category = 'los_santos', min = { -1500, -1400, 0 }, max = { -1050, -900, 60 } },
    { code = 'VCANA', label = 'Vespucci Canals', category = 'los_santos', min = { -1150, -950, 0 }, max = { -850, -600, 60 } },
    { code = 'VINE', label = 'Vinewood', category = 'los_santos', min = { 200, -550, 30 }, max = { 650, -100, 150 } },
    { code = 'WVINE', label = 'West Vinewood', category = 'los_santos', min = { -550, -200, 20 }, max = { -100, 250, 120 } },
    { code = 'DTVINE', label = 'Downtown Vinewood', category = 'los_santos', min = { 50, -450, 30 }, max = { 400, -50, 120 } },
    { code = 'ROCKF', label = 'Rockford Hills', category = 'los_santos', min = { -1300, -650, 0 }, max = { -850, -250, 100 } },
    { code = 'PBOX', label = 'Pillbox Hill', category = 'los_santos', min = { -250, -700, 10 }, max = { 150, -300, 150 } },
    { code = 'KOREAT', label = 'Little Seoul', category = 'los_santos', min = { -450, -1150, 10 }, max = { -150, -800, 60 } },
    { code = 'MIRR', label = 'Mirror Park', category = 'los_santos', min = { 950, -600, 20 }, max = { 1350, -150, 90 } },
    { code = 'MORN', label = 'Morningwood', category = 'los_santos', min = { 600, -100, 30 }, max = { 1000, 300, 120 } },
    { code = 'BURTON', label = 'Burton', category = 'los_santos', min = { -50, 0, 30 }, max = { 350, 400, 130 } },
    { code = 'RICHM', label = 'Richman', category = 'los_santos', min = { -1700, 0, 0 }, max = { -1250, 500, 150 } },
    { code = 'LMESA', label = 'La Mesa', category = 'los_santos', min = { 700, -1350, 10 }, max = { 1150, -900, 60 } },
    { code = 'CYPRE', label = 'Cypress Flats', category = 'los_santos', min = { 550, -2200, 10 }, max = { 950, -1750, 60 } },
    { code = 'ELYSIAN', label = 'Elysian Island', category = 'los_santos', min = { 100, -2900, 0 }, max = { 500, -2450, 50 } },
    { code = 'LOSPUER', label = 'La Puerta', category = 'los_santos', min = { -1650, -1050, 0 }, max = { -1300, -650, 50 } },
    { code = 'CHAMH', label = 'Chamberlain Hills', category = 'los_santos', min = { -350, -1750, 10 }, max = { 0, -1350, 60 } },
    { code = 'EBURO', label = 'El Burro Heights', category = 'los_santos', min = { 1150, -1750, 10 }, max = { 1600, -1300, 70 } },
    { code = 'MURRI', label = 'Murrieta Heights', category = 'los_santos', min = { -500, -1050, 10 }, max = { -150, -700, 60 } },
    { code = 'HAWICK', label = 'Hawick', category = 'los_santos', min = { -750, -450, 10 }, max = { -400, -50, 90 } },
    { code = 'BANNING', label = 'Banning', category = 'los_santos', min = { -350, -450, 10 }, max = { 50, -50, 90 } },
    { code = 'JAIL', label = 'Bolingbroke Penitentiary', category = 'restricted', min = { 1600, 2450, 40 }, max = { 1950, 2900, 100 } },
    { code = 'NOOSE', label = 'N.O.O.S.E.', category = 'restricted', min = { 2400, -450, 0 }, max = { 2750, 0, 60 } },
    { code = 'AIRP', label = 'Los Santos International Airport', category = 'restricted', min = { -1900, -3300, 0 }, max = { -900, -2350, 40 } },
    { code = 'HUMLAB', label = 'Humane Labs and Research', category = 'restricted', min = { 3300, -4750, 0 }, max = { 3800, -4300, 60 } },
    { code = 'GREATC', label = 'Great Chaparral', category = 'wilderness', min = { -600, 950, 100 }, max = { 100, 1750, 350 } },
    { code = 'BEACH', label = 'Vespucci Beach', category = 'los_santos', min = { -1450, -1700, 0 }, max = { -1050, -1400, 60 } },
    { code = 'CHIL', label = 'Vinewood Hills', category = 'los_santos', min = { 150, 150, 50 }, max = { 700, 600, 300 } },
    { code = 'CHU', label = 'Chumash', category = 'los_santos', min = { -3050, 400, 0 }, max = { -2450, 900, 80 } },
    { code = 'NCHU', label = 'North Chumash', category = 'los_santos', min = { -3100, 900, 0 }, max = { -2500, 1400, 120 } },
    { code = 'DELPE', label = 'Del Perro', category = 'los_santos', min = { -1750, -500, 0 }, max = { -1300, -50, 60 } },
    { code = 'DELBE', label = 'Del Perro Beach', category = 'los_santos', min = { -1900, -600, 0 }, max = { -1600, -350, 40 } },
    { code = 'PBLUFF', label = 'Pacific Bluffs', category = 'los_santos', min = { -3200, 900, 0 }, max = { -2700, 1300, 150 } },
    { code = 'GOLF', label = 'GWC and Golfing Society', category = 'los_santos', min = { -1400, -450, 0 }, max = { -1150, -200, 40 } },
    { code = 'HORS', label = 'Vinewood Racetrack', category = 'los_santos', min = { 600, -100, 20 }, max = { 950, 250, 60 } },
    { code = 'LEGSQU', label = 'Legion Square', category = 'los_santos', min = { -250, -950, 20 }, max = { 0, -750, 80 } },
    { code = 'MOVIE', label = 'Richards Majestic', category = 'los_santos', min = { -250, -700, 20 }, max = { 0, -500, 80 } },
    { code = 'RGLEN', label = 'Richman Glen', category = 'los_santos', min = { -1750, 250, 0 }, max = { -1450, 600, 150 } },
    { code = 'RTRAK', label = 'Redwood Lights Track', category = 'los_santos', min = { 1050, -650, 10 }, max = { 1350, -350, 60 } },
    { code = 'STAD', label = 'Maze Bank Arena', category = 'los_santos', min = { -250, -2000, 10 }, max = { 0, -1800, 60 } },
    { code = 'TERMINA', label = 'Terminal', category = 'los_santos', min = { 700, -3000, 0 }, max = { 1050, -2650, 40 } },
    { code = 'TEXTI', label = 'Textile City', category = 'los_santos', min = { 700, -1250, 10 }, max = { 1000, -950, 60 } },
    { code = 'TONGVAH', label = 'Tongva Hills', category = 'wilderness', min = { -1000, 2200, 50 }, max = { -300, 2900, 350 } },
    { code = 'TONGVAV', label = 'Tongva Valley', category = 'wilderness', min = { 0, 2400, 50 }, max = { 700, 3100, 350 } },
    { code = 'ZP_ORT', label = 'Port of South Los Santos', category = 'los_santos', min = { 400, -2750, 0 }, max = { 800, -2450, 40 } },
    { code = 'ZQ_UAR', label = 'Davis Quartz', category = 'los_santos', min = { 100, -1950, 10 }, max = { 400, -1750, 60 } },

    -- ── Conceptual / non-assignable markers (spec §17.1: recognized but explicitly not player territory) ──
    { code = 'OCEANA', label = 'Pacific Ocean', category = 'water', enabled = false, min = { -4000, -6000, -50 }, max = { 4000, 8000, 10 } },
    { code = 'SANAND', label = 'San Andreas', category = 'restricted', enabled = false, min = { -4000, -8000, -500 }, max = { 4000, 8000, 2000 } },
}

-- Fallback bucket for coordinates GetNameOfZone resolves to a code with no
-- entry below yet (extend RAW above rather than relying on this).
Districts.UNKNOWN_CODE = 'UNKNOWN'

-- Duplicate-id detection (spec §17.2) — a copy/paste mistake in RAW above
-- would otherwise silently let the second entry overwrite the first with
-- no signal at all. Exposed via Districts.GetDuplicateCodes() so
-- shared/validators.lua can turn this into a real (or warned) error
-- instead of the file needing its own ad-hoc `error()` call.
local seenCodes = {}
local duplicateCodes = {}
for _, entry in ipairs(RAW) do
    if seenCodes[entry.code] then
        duplicateCodes[#duplicateCodes + 1] = entry.code
    end
    seenCodes[entry.code] = true
end

function Districts.GetDuplicateCodes()
    return duplicateCodes
end

local byCode = {}
for _, entry in ipairs(RAW) do
    byCode[entry.code] = {
        id = entry.code,           -- spec §17 DISTRICT MODEL field name
        code = entry.code,         -- kept as an alias — every Phase 1-16 call site
                                    -- (client/server zone_resolver.lua, validators.lua,
                                    -- debug.lua) reads `.code`, not `.id`
        label = entry.label,
        enabled = entry.enabled ~= false, -- default true unless explicitly false
        category = entry.category or 'los_santos',
        resolver = Constants.Resolver.GTA_NATIVE,
        defaultGrid = nil,         -- filled in by Districts.ComputeAssignments() once Grids loads (see shared/grids.lua tail)
        visualProfile = nil,       -- §28.1 override, nil = use the owning grid's profile (Phase 28, not read anywhere yet)
        metadata = {},
        aabbConfidence = 'approx', -- see file header — none of these are calibrated yet
        aabb = {
            min = vector3(entry.min[1], entry.min[2], entry.min[3]),
            max = vector3(entry.max[1], entry.max[2], entry.max[3]),
        },
    }
end

Districts.ByCode = byCode

-- Pre-sorted (ascending volume) list for server-side lookup — smallest
-- box is tested first so a nested district "wins" over its container
-- without an explicit priority field. Built once at load time.
local sortedList = {}
for _, entry in pairs(byCode) do
    sortedList[#sortedList + 1] = entry
end
table.sort(sortedList, function(a, b)
    return Utils.AABBVolume(a.aabb.min, a.aabb.max) < Utils.AABBVolume(b.aabb.min, b.aabb.max)
end)
Districts.SortedByVolume = sortedList

function Districts.GetLabel(code)
    local entry = byCode[code]
    return entry and entry.label or code
end

function Districts.Exists(code)
    return byCode[code] ~= nil
end

function Districts.GetAllEnabled()
    local list = {}
    for code, entry in pairs(byCode) do
        if entry.enabled then list[#list + 1] = code end
    end
    table.sort(list)
    return list
end

-- Assignment status (spec §17.1: "sessiz fallback yapılmamalıdır" — a
-- recognized-but-unassigned district must be explicitly flagged, not
-- silently treated as powered/unpowered). Populated by
-- Districts.ComputeAssignments() below, called AFTER shared/grids.lua has
-- loaded and frozen Grids (this file loads BEFORE shared/grids.lua in
-- fxmanifest.lua's shared_scripts list, so it cannot know grid membership
-- at its own load time) — see the call at the tail of shared/grids.lua.
local assignmentByCode = {}

function Districts.GetAssignment(code)
    if not byCode[code] then return 'UNKNOWN' end
    return assignmentByCode[code] or 'UNASSIGNED'
end

-- Walks every grid's `districts` list once and marks every claimed
-- district as ASSIGNED (also back-filling `defaultGrid`, since a
-- district's grid IS its default grid — there's no separate concept yet).
-- Disabled entries (OCEANA/SANAND) are left UNASSIGNED without complaint —
-- see the RAW table's category comment above; they were never meant to be
-- claimed by a grid.
function Districts.ComputeAssignments(grids)
    assignmentByCode = {}
    for gridId, grid in pairs(grids) do
        for _, code in ipairs(grid.districts or {}) do
            local entry = byCode[code]
            if entry then
                assignmentByCode[code] = 'ASSIGNED'
                entry.defaultGrid = gridId
            end
        end
    end
end

Utils.FreezeShape(Districts)
