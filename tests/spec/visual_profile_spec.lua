-- Phase 28 profile resolution tests.

local realGrids = Grids
local realProfiles = VisualProfiles
local resolveProfiles = VisualProfiles.Resolve

TEST('district visual profile has priority over grid profile', function()
    Grids = { grid_a = { visual = { profile = 'ls_central' } } }
    VisualProfiles = {
        districtProfiles = { DOWNT = 'downtown' },
        downtown = { mode = Constants.VisualMode.HYBRID },
        ls_central = { mode = Constants.VisualMode.NATIVE_CLIENT_GATE },
        native_default = { mode = Constants.VisualMode.NATIVE_CLIENT_GATE },
        Resolve = resolveProfiles,
    }

    local name, profile = VisualProfiles.Resolve('DOWNT', 'grid_a')
    ASSERT_EQ(name, 'downtown')
    ASSERT_EQ(profile.mode, Constants.VisualMode.HYBRID)
end)

TEST('grid visual profile is used when district has no registry profile', function()
    Grids = { grid_a = { visual = { profile = 'ls_central' } } }
    VisualProfiles = {
        districtProfiles = {},
        ls_central = { mode = Constants.VisualMode.NATIVE_CLIENT_GATE },
        native_default = { mode = Constants.VisualMode.NATIVE_CLIENT_GATE },
        Resolve = resolveProfiles,
    }

    local name = VisualProfiles.Resolve('SANDY', 'grid_a')
    ASSERT_EQ(name, 'ls_central')
end)

TEST('native default is used when district and grid profiles are missing', function()
    Grids = { grid_a = { visual = { profile = 'missing' } } }
    VisualProfiles = {
        districtProfiles = {},
        native_default = { mode = Constants.VisualMode.NATIVE_CLIENT_GATE },
        Resolve = resolveProfiles,
    }

    local name, profile = VisualProfiles.Resolve('UNKNOWN', 'grid_a')
    ASSERT_EQ(name, 'native_default')
    ASSERT_EQ(profile.mode, Constants.VisualMode.NATIVE_CLIENT_GATE)
end)

Grids = realGrids
VisualProfiles = realProfiles
