--[[
    shared/visual_profile_resolver.lua

    Phase 28 visual selection is a pure lookup. Logical power state remains
    server-owned; this module only resolves the client profile.

    Priority: district profile -> grid profile -> native default.
]]

VisualProfiles = VisualProfiles or {}

VisualProfiles.native_default = VisualProfiles.native_default or {
    mode = Constants.VisualMode.NATIVE_CLIENT_GATE,
    nativeBlackout = {
        enabled = true,
        affectVehicles = false,
    },
}

VisualProfiles.downtown = VisualProfiles.downtown or {
    mode = Constants.VisualMode.HYBRID,
    districts = { 'DOWNT' },
    nativeBlackout = {
        enabled = true,
        affectVehicles = false,
    },
    fallback = 'NATIVE_CLIENT_GATE',
}

VisualProfiles.pillbox = VisualProfiles.pillbox or {
    mode = Constants.VisualMode.HYBRID,
    districts = { 'PBOX' },
    nativeBlackout = {
        enabled = true,
        affectVehicles = false,
    },
    fallback = 'NATIVE_CLIENT_GATE',
}

VisualProfiles.districtProfiles = VisualProfiles.districtProfiles or {
    DOWNT = 'downtown',
    PBOX = 'pillbox',
}

local function normalizeId(value)
    if type(value) ~= 'string' then return nil end
    return string.upper(value)
end

function VisualProfiles.Resolve(districtId, gridId)
    local districtKey = normalizeId(districtId)
    local districtProfileName = districtKey and VisualProfiles.districtProfiles[districtKey]
    local districtProfile = districtProfileName and VisualProfiles[districtProfileName]
    if districtProfile then
        return districtProfileName, districtProfile
    end

    local grid = gridId and Grids[gridId]
    local gridProfileName = grid and grid.visual and grid.visual.profile
    local gridProfile = gridProfileName and VisualProfiles[gridProfileName]
    if gridProfile then
        return gridProfileName, gridProfile
    end

    return 'native_default', VisualProfiles.native_default
end
