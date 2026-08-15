--[[
    shared/regions.lua

    Coarse operational regions used by the admin control surface. A region is
    intentionally a group of GTA district codes, not a replacement for the
    native district resolver. This keeps region actions explicit and makes
    overlapping actions predictable (for example, a city blackout can remain
    active while a smaller Vinewood action is restored).
]]

PowerRegions = {}

local function makeSet(values)
    local result = {}
    for _, value in ipairs(values or {}) do result[value] = true end
    return result
end

local REGION_DEFINITIONS = {
    {
        id = 'city',
        label = 'Los Santos Şehri',
        description = 'Haritadaki Los Santos şehir sınırı içindeki tüm elektrik bölgeleri; Tataviam Mountains dahil.',
        matcher = function(entry) return entry.category == 'los_santos' end,
        include = { 'NOOSE', 'AIRP', 'TATAMO' },
        exclude = { 'CHU', 'NCHU' },
    },
    {
        id = 'towns',
        label = 'Kuzey Kasabaları',
        description = 'Sandy Shores, Harmony, Grapeseed, Paleto ve diğer kasaba bölgeleri.',
        matcher = function(entry) return entry.category == 'blaine_county' end,
    },
    {
        id = 'south',
        label = 'South Side',
        description = 'Güney Los Santos mahallelerinin tamamı.',
        include = {
            'DAVIS', 'RANCHO', 'STRAW', 'CHAMH', 'LMESA', 'CYPRE',
            'EBURO', 'BANNING', 'ELYSIAN', 'LOSPUER',
        },
    },
    {
        id = 'vinewood',
        label = 'Vinewood',
        description = 'Vinewood, tepeler ve Vinewood çevresindeki mahalleler.',
        include = { 'VINE', 'WVINE', 'DTVINE', 'CHIL', 'HAWICK', 'BURTON', 'MORN', 'MIRR', 'MOVIE' },
    },
    {
        id = 'north',
        label = 'Kuzey Bölgesi',
        description = 'Kuzeydeki kasaba, kırsal ve güvenlik bölgelerinin tamamı.',
        matcher = function(entry)
            return entry.category == 'blaine_county'
                or entry.category == 'wilderness'
                or entry.category == 'restricted'
        end,
        include = { 'CHU', 'NCHU' },
        exclude = { 'AIRP', 'NOOSE' },
    },
}

local function collectDistricts(definition)
    local selected = {}
    local excluded = makeSet(definition.exclude)

    for _, code in ipairs(Districts.GetAllEnabled()) do
        local entry = Districts.ByCode[code]
        if entry and definition.matcher and definition.matcher(entry, code) then
            selected[code] = true
        end
    end

    for _, code in ipairs(definition.include or {}) do
        if Districts.Exists(code) and Districts.ByCode[code].enabled ~= false then
            selected[code] = true
        end
    end

    for code in pairs(excluded) do selected[code] = nil end

    local districts = {}
    local districtSet = {}
    for code in pairs(selected) do
        districts[#districts + 1] = code
        districtSet[code] = true
    end
    table.sort(districts)
    return districts, districtSet
end

PowerRegions.ById = {}
PowerRegions.Order = {}

for _, definition in ipairs(REGION_DEFINITIONS) do
    local districts, districtSet = collectDistricts(definition)
    local region = {
        id = definition.id,
        label = definition.label,
        description = definition.description,
        districts = districts,
        districtSet = districtSet,
    }
    PowerRegions.ById[region.id] = region
    PowerRegions.Order[#PowerRegions.Order + 1] = region.id
end

function PowerRegions.Get(regionId)
    return PowerRegions.ById[regionId]
end

function PowerRegions.GetAll()
    local result = {}
    for _, regionId in ipairs(PowerRegions.Order) do
        result[#result + 1] = PowerRegions.ById[regionId]
    end
    return result
end

function PowerRegions.GetRegionsForDistrict(districtCode)
    local result = {}
    for _, regionId in ipairs(PowerRegions.Order) do
        local region = PowerRegions.ById[regionId]
        if region and region.districtSet[districtCode] then
            result[#result + 1] = region
        end
    end
    return result
end
