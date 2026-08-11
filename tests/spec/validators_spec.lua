--[[
    tests/spec/validators_spec.lua

    Exercises shared/validators.lua against small synthetic Grids/
    Substations/Transformers fixtures — NOT the real shared/grids.lua
    (see tests/run.lua header for why that file can't be loaded under
    stock Lua). Districts.Exists() checks use the REAL shared/districts.lua
    table (SANDY/HARMO/etc. are real codes in it).

    Each test sets its own fixtures via resetFixtures() + overrides, then
    restores empty fixtures afterward so tests don't leak into each other.
]]

local realGrids = Grids
local realSubstations = Substations
local realTransformers = Transformers
local realFeeders = Feeders
local realInfrastructureWorld = InfrastructureWorld
local realVisualProfiles = VisualProfiles
local realZones = Config.Zones

local function resetFixtures()
    Grids = {}
    Substations = {}
    Transformers = {}
    Feeders = {}
    InfrastructureWorld = nil
    Config.Zones = {}
    VisualProfiles = nil
end

local function validMinimalGrid()
    Grids['test_grid'] = {
        label = 'Test Grid',
        resolver = Constants.Resolver.GTA_NATIVE,
        districts = { 'SANDY' },
        substations = { 'test_sub' },
        powerPolicy = { mode = Constants.PowerPolicy.PRIMARY },
        visual = { profile = 'test_profile' },
    }
    Substations['test_sub'] = {
        gridId = 'test_grid',
        label = 'Test Substation',
        transformers = { 'test_tr' },
    }
    Transformers['test_tr'] = {
        substationId = 'test_sub',
        label = 'Test Transformer',
        primary = true,
    }
end

TEST('valid minimal grid passes validation', function()
    resetFixtures()
    validMinimalGrid()

    local ok, errors = Validators.ValidateAll()
    ASSERT_TRUE(ok, 'expected valid config to pass, errors: ' .. table.concat(errors or {}, ' | '))
end)

TEST('grid referencing unknown district fails', function()
    resetFixtures()
    validMinimalGrid()
    Grids['test_grid'].districts = { 'NOT_A_REAL_DISTRICT' }

    local ok = Validators.ValidateAll()
    ASSERT_FALSE(ok)
end)

TEST('two grids claiming the same district fails (spec §6)', function()
    resetFixtures()
    validMinimalGrid()
    Grids['other_grid'] = {
        label = 'Other Grid',
        resolver = Constants.Resolver.GTA_NATIVE,
        districts = { 'SANDY' }, -- same district as test_grid
        substations = { 'other_sub' },
        powerPolicy = { mode = Constants.PowerPolicy.ANY },
        visual = { profile = 'test_profile' },
    }
    Substations['other_sub'] = { gridId = 'other_grid', transformers = { 'other_tr' } }
    Transformers['other_tr'] = { substationId = 'other_sub', primary = false }

    local ok = Validators.ValidateAll()
    ASSERT_FALSE(ok)
end)

TEST('REQUIRED_COUNT requiredOnline exceeding transformer count fails', function()
    resetFixtures()
    validMinimalGrid()
    Grids['test_grid'].powerPolicy = { mode = Constants.PowerPolicy.REQUIRED_COUNT, requiredOnline = 5 }

    local ok = Validators.ValidateAll()
    ASSERT_FALSE(ok)
end)

TEST('REQUIRED_COUNT with a satisfiable requirement passes', function()
    resetFixtures()
    validMinimalGrid()
    Grids['test_grid'].powerPolicy = { mode = Constants.PowerPolicy.REQUIRED_COUNT, requiredOnline = 1 }

    local ok = Validators.ValidateAll()
    ASSERT_TRUE(ok)
end)

TEST('PRIMARY policy with no primary transformer fails', function()
    resetFixtures()
    validMinimalGrid()
    Transformers['test_tr'].primary = false

    local ok = Validators.ValidateAll()
    ASSERT_FALSE(ok)
end)

TEST('WEIGHTED_CAPACITY (not implemented) is rejected', function()
    resetFixtures()
    validMinimalGrid()
    Grids['test_grid'].powerPolicy = { mode = Constants.PowerPolicy.WEIGHTED_CAPACITY, minimumCapacity = 0.5 }

    local ok = Validators.ValidateAll()
    ASSERT_FALSE(ok)
end)

TEST('substation pointing at a different grid than its parent fails', function()
    resetFixtures()
    validMinimalGrid()
    Substations['test_sub'].gridId = 'some_other_grid'

    local ok = Validators.ValidateAll()
    ASSERT_FALSE(ok)
end)

TEST('grid with no substations fails', function()
    resetFixtures()
    validMinimalGrid()
    Grids['test_grid'].substations = {}

    local ok = Validators.ValidateAll()
    ASSERT_FALSE(ok)
end)

TEST('visual profile referencing an unloaded profile fails when VisualProfiles is populated', function()
    resetFixtures()
    validMinimalGrid()
    VisualProfiles = { some_other_profile = {} } -- 'test_profile' referenced by the grid is missing

    local ok = Validators.ValidateAll()
    ASSERT_FALSE(ok)
end)

TEST('custom zone with invalid type fails', function()
    resetFixtures()
    validMinimalGrid()
    Config.Zones = { { id = 'bad_zone', type = 'triangle', gridId = 'test_grid' } }

    local ok = Validators.ValidateAll()
    ASSERT_FALSE(ok)
end)

TEST('custom polygon zone with fewer than 3 points fails', function()
    resetFixtures()
    validMinimalGrid()
    Config.Zones = {
        { id = 'bad_poly', type = Constants.Resolver.POLYGON, gridId = 'test_grid', points = { { x = 0, y = 0 }, { x = 1, y = 1 } } },
    }

    local ok = Validators.ValidateAll()
    ASSERT_FALSE(ok)
end)

TEST('custom radius zone with valid shape passes', function()
    resetFixtures()
    validMinimalGrid()
    Config.Zones = {
        { id = 'good_radius', type = Constants.Resolver.RADIUS, gridId = 'test_grid', center = { x = 0, y = 0 }, radius = 10 },
    }

    local ok = Validators.ValidateAll()
    ASSERT_TRUE(ok)
end)

-- Leave globals in a clean state for anything loaded after this file.
resetFixtures()
Grids = realGrids
Substations = realSubstations
Transformers = realTransformers
Feeders = realFeeders
InfrastructureWorld = realInfrastructureWorld
VisualProfiles = realVisualProfiles
Config.Zones = realZones
