--[[
    shared/validators.lua

    Config schema validation, run once at resource start (server/main.lua)
    BEFORE anything is published to GlobalState. Per the plan's Phase 1
    acceptance criterion: a broken config must fail loudly and refuse to
    publish state — a half-configured grid silently going "powered" is
    worse than the resource refusing to start.

    Validators.ValidateAll() returns (ok: boolean, errors: string[]).
]]

Validators = {}

local function addError(errors, fmt, ...)
    errors[#errors + 1] = fmt:format(...)
end

local function isFiniteNumber(value)
    return type(value) == 'number'
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function validateRandomFailure(errors)
    local config = Config.RandomFailure
    if type(config) ~= 'table' then
        addError(errors, 'Config.RandomFailure must be a table')
        return
    end

    if type(config.enabled) ~= 'boolean' then
        addError(errors, 'Config.RandomFailure.enabled must be boolean')
    end

    if not isFiniteNumber(config.tickSec) or config.tickSec < 1 then
        addError(errors, 'Config.RandomFailure.tickSec must be a number >= 1')
    end

    local weights = {
        transformerWeight = config.transformerWeight,
        feederWeight = config.feederWeight,
        substationWeight = config.substationWeight,
    }
    local totalWeight = 0
    for name, weight in pairs(weights) do
        if not isFiniteNumber(weight) or weight < 0 then
            addError(errors, 'Config.RandomFailure.%s must be a finite number >= 0', name)
        else
            totalWeight = totalWeight + weight
        end
    end

    if config.enabled == true and totalWeight <= 0 then
        addError(errors, 'Config.RandomFailure needs at least one positive target weight when enabled')
    end

    if not isFiniteNumber(config.maxAutomaticOfflineDistricts)
        or config.maxAutomaticOfflineDistricts < 1
        or math.floor(config.maxAutomaticOfflineDistricts) ~= config.maxAutomaticOfflineDistricts then
        addError(errors, 'Config.RandomFailure.maxAutomaticOfflineDistricts must be a positive integer')
    end

    if not isFiniteNumber(config.cooldownSec) or config.cooldownSec < 0 then
        addError(errors, 'Config.RandomFailure.cooldownSec must be a finite number >= 0')
    end
end

local function validateSecurity(errors)
    local config = Config.Security
    if type(config) ~= 'table' then
        addError(errors, 'Config.Security must be a table')
        return
    end

    if type(config.enabled) ~= 'boolean' then
        addError(errors, 'Config.Security.enabled must be boolean')
    end

    local numbers = {
        maxStringLength = config.maxStringLength,
        rateWindowSec = config.rateWindowSec,
        maxEventsPerWindow = config.maxEventsPerWindow,
        auditWindowSec = config.auditWindowSec,
        maxSessionTtlSec = config.maxSessionTtlSec,
    }
    for name, value in pairs(numbers) do
        if not isFiniteNumber(value) or value <= 0 then
            addError(errors, 'Config.Security.%s must be a finite number > 0', name)
        end
    end

    if isFiniteNumber(config.maxStringLength)
        and math.floor(config.maxStringLength) ~= config.maxStringLength then
        addError(errors, 'Config.Security.maxStringLength must be an integer')
    end

    if isFiniteNumber(config.maxEventsPerWindow)
        and math.floor(config.maxEventsPerWindow) ~= config.maxEventsPerWindow then
        addError(errors, 'Config.Security.maxEventsPerWindow must be an integer')
    end
end

local function validateDebug(errors)
    local config = Config.Debug
    if type(config) ~= 'table' then
        addError(errors, 'Config.Debug must be a table')
        return
    end

    if type(config.enabled) ~= 'boolean' then
        addError(errors, 'Config.Debug.enabled must be boolean')
    end
    if type(config.adminGroup) ~= 'string' or config.adminGroup == '' then
        addError(errors, 'Config.Debug.adminGroup must be a non-empty string')
    end
    if config.convar ~= nil and (type(config.convar) ~= 'string' or config.convar == '') then
        addError(errors, 'Config.Debug.convar must be a non-empty string when configured')
    end
end

local function validateMetrics(errors)
    local config = Config.Metrics
    if type(config) ~= 'table' then
        addError(errors, 'Config.Metrics must be a table')
        return
    end
    if type(config.enabled) ~= 'boolean' then
        addError(errors, 'Config.Metrics.enabled must be boolean')
    end
    local numbers = {
        sampleIntervalSec = config.sampleIntervalSec,
        maxSamples = config.maxSamples,
    }
    for name, value in pairs(numbers) do
        if not isFiniteNumber(value) or value <= 0 or math.floor(value) ~= value then
            addError(errors, 'Config.Metrics.%s must be a positive integer', name)
        end
    end
end

-- Grid -> substation -> transformer reference integrity, district
-- existence, and no-district-claimed-by-two-grids (spec §6: a district
-- belongs to exactly one grid).
local function validateTopology(errors)
    local districtOwner = {}

    for gridId, grid in pairs(Grids) do
        if type(grid.districts) ~= 'table' or #grid.districts == 0 then
            addError(errors, "grid '%s' has no districts assigned", gridId)
        else
            for _, code in ipairs(grid.districts) do
                if not Districts.Exists(code) then
                    addError(errors, "grid '%s' references unknown district '%s' (add it to shared/districts.lua)", gridId, code)
                elseif districtOwner[code] then
                    addError(errors, "district '%s' is claimed by both grid '%s' and grid '%s' (spec §6: one district -> one grid)", code, districtOwner[code], gridId)
                else
                    districtOwner[code] = gridId
                end
            end
        end

        if type(grid.substations) ~= 'table' or #grid.substations == 0 then
            addError(errors, "grid '%s' has no substations assigned", gridId)
        else
            for _, subId in ipairs(grid.substations) do
                local sub = Substations[subId]
                if not sub then
                    addError(errors, "grid '%s' references unknown substation '%s'", gridId, subId)
                elseif sub.gridId ~= gridId then
                    addError(errors, "substation '%s' lists gridId '%s' but grid '%s' also claims it", subId, sub.gridId, gridId)
                end
            end
        end

        if not grid.resolver or not (grid.resolver == Constants.Resolver.GTA_NATIVE
            or grid.resolver == Constants.Resolver.POLYGON
            or grid.resolver == Constants.Resolver.RADIUS) then
            addError(errors, "grid '%s' has invalid resolver '%s'", gridId, tostring(grid.resolver))
        end
    end

    for subId, sub in pairs(Substations) do
        if not Grids[sub.gridId] then
            addError(errors, "substation '%s' references unknown grid '%s'", subId, sub.gridId)
        end
        if type(sub.transformers) ~= 'table' or #sub.transformers == 0 then
            addError(errors, "substation '%s' has no transformers assigned", subId)
        else
            for _, trId in ipairs(sub.transformers) do
                local tr = Transformers[trId]
                if not tr then
                    addError(errors, "substation '%s' references unknown transformer '%s'", subId, trId)
                elseif tr.substationId ~= subId then
                    addError(errors, "transformer '%s' lists substationId '%s' but substation '%s' also claims it", trId, tr.substationId, subId)
                end
            end
        end
    end

    for trId, tr in pairs(Transformers) do
        if not Substations[tr.substationId] then
            addError(errors, "transformer '%s' references unknown substation '%s'", trId, tr.substationId)
        end
    end
end

-- powerPolicy shape must match its declared mode (spec §15).
local function validatePowerPolicies(errors)
    for gridId, grid in pairs(Grids) do
        local policy = grid.powerPolicy
        if not policy or not policy.mode then
            addError(errors, "grid '%s' has no powerPolicy.mode", gridId)
        elseif policy.mode == Constants.PowerPolicy.REQUIRED_COUNT then
            local transformerCount = 0
            for _, subId in ipairs(grid.substations or {}) do
                local sub = Substations[subId]
                if sub then transformerCount = transformerCount + #(sub.transformers or {}) end
            end
            if type(policy.requiredOnline) ~= 'number' or policy.requiredOnline < 1 then
                addError(errors, "grid '%s' powerPolicy REQUIRED_COUNT needs a numeric requiredOnline >= 1", gridId)
            elseif policy.requiredOnline > transformerCount then
                addError(errors, "grid '%s' powerPolicy requiredOnline (%d) exceeds its transformer count (%d)", gridId, policy.requiredOnline, transformerCount)
            end
        elseif policy.mode == Constants.PowerPolicy.WEIGHTED_CAPACITY then
            -- Reserved for a later phase (spec §73: "sonraki iteration").
            addError(errors, "grid '%s' uses powerPolicy mode WEIGHTED_CAPACITY, which is not implemented yet (Phase 6 ships PRIMARY/ANY/ALL/REQUIRED_COUNT only)", gridId)
        elseif policy.mode == Constants.PowerPolicy.PRIMARY_BACKUP or policy.mode == Constants.PowerPolicy.CUSTOM then
            addError(errors, "grid '%s' uses powerPolicy mode '%s', which is not implemented yet", gridId, policy.mode)
        elseif policy.mode == Constants.PowerPolicy.PRIMARY then
            local hasPrimary = false
            for _, subId in ipairs(grid.substations or {}) do
                local sub = Substations[subId]
                if sub then
                    for _, trId in ipairs(sub.transformers or {}) do
                        local tr = Transformers[trId]
                        if tr and tr.primary then hasPrimary = true end
                    end
                end
            end
            if not hasPrimary then
                addError(errors, "grid '%s' uses powerPolicy PRIMARY but no transformer under it has primary = true", gridId)
            end
        elseif policy.mode ~= Constants.PowerPolicy.ANY and policy.mode ~= Constants.PowerPolicy.ALL then
            addError(errors, "grid '%s' has unknown powerPolicy.mode '%s'", gridId, tostring(policy.mode))
        end
    end
end

-- visual.profile must point at a file profiles/<name>.lua that actually
-- got loaded (loader populates VisualProfiles — see client/visual/manager.lua).
local function validateVisualProfiles(errors)
    for gridId, grid in pairs(Grids) do
        if not grid.visual or not grid.visual.profile then
            addError(errors, "grid '%s' has no visual.profile assigned", gridId)
        elseif VisualProfiles and not VisualProfiles[grid.visual.profile] then
            addError(errors, "grid '%s' references visual profile '%s' which was not loaded (check profiles/%s.lua and fxmanifest.lua)", gridId, grid.visual.profile, grid.visual.profile)
        end
    end
end

-- Config.Zones shape validation (spec §8, §9).
local function validateCustomZones(errors)
    for _, zone in ipairs(Config.Zones or {}) do
        if not zone.id then
            addError(errors, "a Config.Zones entry is missing 'id'")
        end
        if zone.type ~= Constants.Resolver.POLYGON and zone.type ~= Constants.Resolver.RADIUS then
            addError(errors, "zone '%s' has invalid type '%s' (expected 'polygon' or 'radius')", tostring(zone.id), tostring(zone.type))
        end
        if zone.gridId and not Grids[zone.gridId] then
            addError(errors, "zone '%s' references unknown gridId '%s'", tostring(zone.id), tostring(zone.gridId))
        end
        if zone.type == Constants.Resolver.POLYGON then
            if type(zone.points) ~= 'table' or #zone.points < 3 then
                addError(errors, "zone '%s' (polygon) needs at least 3 points", tostring(zone.id))
            end
        elseif zone.type == Constants.Resolver.RADIUS then
            if type(zone.center) ~= 'table' then
                addError(errors, "zone '%s' (radius) needs a 'center' point", tostring(zone.id))
            end
            if type(zone.radius) ~= 'number' or zone.radius <= 0 then
                addError(errors, "zone '%s' (radius) needs a positive numeric 'radius'", tostring(zone.id))
            end
        end
    end
end

-- District registry validation (spec §17.2, Phase 17). Config.Topology.strict
-- decides whether a finding lands in `errors` (blocks boot, same severity
-- as a broken grid->substation reference) or `warnings` (printed, resource
-- still starts — matches how shared/districts.lua's own AABB accuracy gap
-- has always been handled: documented and visible, not fatal).
local function validateDistrictRegistry(errors, warnings)
    local function report(fmt, ...)
        local msg = fmt:format(...)
        if Config.Topology and Config.Topology.strict then
            addError(errors, '%s', msg)
        else
            warnings[#warnings + 1] = msg
        end
    end

    for _, dupCode in ipairs(Districts.GetDuplicateCodes()) do
        -- Always a hard error regardless of strict mode — a duplicate id
        -- silently drops data (the first entry never got built), not
        -- something a server operator would want to merely be warned
        -- about and keep running with.
        addError(errors, "district code '%s' appears more than once in shared/districts.lua (RAW table) — second entry silently won", dupCode)
    end

    for code, entry in pairs(Districts.ByCode) do
        if not entry.label or entry.label == '' then
            report("district '%s' has no label", code)
        end
        if not entry.resolver or entry.resolver ~= Constants.Resolver.GTA_NATIVE then
            report("district '%s' has invalid resolver '%s'", code, tostring(entry.resolver))
        end
        if entry.enabled and Districts.GetAssignment(code) == 'UNASSIGNED' then
            -- spec §17.2's example warning text, verbatim in spirit:
            -- "[Infrastructure] WARNING: District X has no power topology assignment."
            report('District %s has no power topology assignment.', code)
        end
    end

    -- The inverse case: a grid claims a district that's registered but
    -- disabled (spec §17.2 "disabled district?" check) — validateTopology()
    -- above already catches a district that doesn't EXIST at all; this
    -- catches one that exists but was explicitly turned off.
    for gridId, grid in pairs(Grids) do
        for _, code in ipairs(grid.districts or {}) do
            local entry = Districts.ByCode[code]
            if entry and not entry.enabled then
                report("grid '%s' claims district '%s' which is registered but disabled (enabled = false)", gridId, code)
            end
        end
    end
end

-- Feeder topology validation (spec §18.5, Phase 18). Circular topology
-- ("feeder -> substation -> grid" forming a loop) is NOT checked here —
-- it's structurally impossible in this schema: a feeder only points AT a
-- substation by id (feeder.substationId), and neither Substations nor
-- Transformers know feeders exist at all, so there is no reference path
-- that could ever point back at a feeder. Writing a cycle-detection graph
-- walk for a shape that can't contain a cycle would be dead code, not
-- defensive programming.
local function validateFeederTopology(errors, warnings)
    local function report(fmt, ...)
        local msg = fmt:format(...)
        if Config.Topology and Config.Topology.strict then
            addError(errors, '%s', msg)
        else
            warnings[#warnings + 1] = msg
        end
    end

    -- §18.6: every enabled, grid-assigned district needs at least one
    -- feeder covering it OR falls back to grid-level power (Phase 1-17
    -- behavior) — Config.Topology.warnUnassignedDistricts controls whether
    -- that fallback gets a visible warning.
    local districtFedBy = {}

    for feederId, feeder in pairs(Feeders or {}) do
        if not feeder.substationId or not Substations[feeder.substationId] then
            addError(errors, "feeder '%s' references unknown substation '%s'", feederId, tostring(feeder.substationId))
        end

        if type(feeder.transformers) ~= 'table' or #feeder.transformers == 0 then
            addError(errors, "feeder '%s' has no transformers assigned", feederId)
        else
            for _, trId in ipairs(feeder.transformers) do
                local tr = Transformers[trId]
                if not tr then
                    addError(errors, "feeder '%s' references unknown transformer '%s'", feederId, trId)
                elseif tr.substationId ~= feeder.substationId then
                    addError(errors, "feeder '%s' claims transformer '%s', but that transformer belongs to substation '%s', not '%s'", feederId, trId, tr.substationId, tostring(feeder.substationId))
                end
            end
        end

        if type(feeder.districts) ~= 'table' or #feeder.districts == 0 then
            addError(errors, "feeder '%s' has no districts assigned", feederId)
        else
            for _, code in ipairs(feeder.districts) do
                if not Districts.Exists(code) then
                    addError(errors, "feeder '%s' references unknown district '%s'", feederId, code)
                else
                    districtFedBy[code] = true
                end
            end
        end

        local policy = feeder.powerPolicy
        if not policy or not policy.mode then
            addError(errors, "feeder '%s' has no powerPolicy.mode", feederId)
        elseif policy.mode == Constants.PowerPolicy.PRIMARY then
            local hasPrimary = false
            for _, trId in ipairs(feeder.transformers or {}) do
                local tr = Transformers[trId]
                if tr and tr.primary then hasPrimary = true end
            end
            if not hasPrimary then
                addError(errors, "feeder '%s' uses powerPolicy PRIMARY but no transformer under it has primary = true", feederId)
            end
        elseif policy.mode ~= Constants.PowerPolicy.ANY and policy.mode ~= Constants.PowerPolicy.ALL and policy.mode ~= Constants.PowerPolicy.REQUIRED_COUNT then
            addError(errors, "feeder '%s' uses powerPolicy mode '%s', which is not implemented yet", feederId, tostring(policy.mode))
        end
    end

    if Config.Topology and Config.Topology.warnUnassignedDistricts then
        for gridId, grid in pairs(Grids) do
            for _, code in ipairs(grid.districts or {}) do
                if not districtFedBy[code] then
                    report("district '%s' belongs to grid '%s' but is not covered by any feeder — falling back to grid-level power (Phase 1-17 behavior)", code, gridId)
                end
            end
        end
    end
end

-- Physical placement validation (spec §22). Runtime model/district checks
-- belong to the client because the server has no reliable GTA world native;
-- this pass only validates the static registry and its topology links.
local function validateWorldPlacement(errors)
    if not InfrastructureWorld then return end

    local function validNumber(value)
        return type(value) == 'number' and value == value and math.abs(value) < 1000000
    end

    local function validCoords(coords)
        return coords
            and validNumber(coords.x)
            and validNumber(coords.y)
            and validNumber(coords.z)
    end

    local function hasValue(list, value)
        for _, candidate in ipairs(list or {}) do
            if candidate == value then return true end
        end
        return false
    end

    local seenCoordinates = {}
    local expectedIds = {}

    for logicalId, point in pairs(InfrastructureWorld) do
        -- The registry table may not contain helper members today, but this
        -- guard keeps validation safe if metadata is added later.
        if type(point) == 'table' then
            expectedIds[logicalId] = true

            if point.logicalId ~= logicalId then
                addError(errors, "world point key '%s' disagrees with logicalId '%s'", logicalId, tostring(point.logicalId))
            end

            if point.type ~= 'transformer' and point.type ~= 'substation' then
                addError(errors, "world point '%s' has invalid type '%s'", logicalId, tostring(point.type))
            end

            if not validCoords(point.coords) then
                addError(errors, "world point '%s' has invalid coords", logicalId)
            else
                for otherId, otherCoords in pairs(seenCoordinates) do
                    if Utils.Distance3D(point.coords, otherCoords) < 0.5 then
                        addError(errors, "world points '%s' and '%s' are duplicate/too close", logicalId, otherId)
                    end
                end
                seenCoordinates[logicalId] = point.coords
            end

            if not validNumber(point.heading) then
                addError(errors, "world point '%s' has invalid heading", logicalId)
            end
            if type(point.enabled) ~= 'boolean' then
                addError(errors, "world point '%s' needs boolean enabled", logicalId)
            end
            if type(point.interactionRadius) ~= 'number' or point.interactionRadius <= 0 then
                addError(errors, "world point '%s' needs positive interactionRadius", logicalId)
            end
            if type(point.visualRadius) ~= 'number' or point.visualRadius <= 0 then
                addError(errors, "world point '%s' needs positive visualRadius", logicalId)
            elseif type(point.interactionRadius) == 'number' and point.visualRadius < point.interactionRadius then
                addError(errors, "world point '%s' visualRadius cannot be smaller than interactionRadius", logicalId)
            end

            if point.type == 'transformer' then
                local transformer = Transformers[logicalId]
                if not transformer then
                    addError(errors, "world point '%s' references unknown transformer", logicalId)
                else
                    local substation = Substations[transformer.substationId]
                    if point.substationId ~= transformer.substationId then
                        addError(errors, "world transformer '%s' has wrong substationId '%s'", logicalId, tostring(point.substationId))
                    end
                    if not substation or point.gridId ~= substation.gridId then
                        addError(errors, "world transformer '%s' has wrong gridId '%s'", logicalId, tostring(point.gridId))
                    end
                    if not point.feederId or not Feeders[point.feederId] then
                        addError(errors, "world transformer '%s' needs a valid feederId", logicalId)
                    else
                        local feederClaimsTransformer = false
                        for _, transformerId in ipairs(Feeders[point.feederId].transformers or {}) do
                            if transformerId == logicalId then feederClaimsTransformer = true end
                        end
                        if not feederClaimsTransformer then
                            addError(errors, "world transformer '%s' is not claimed by feeder '%s'", logicalId, point.feederId)
                        end
                    end
                    if type(point.model) ~= 'string' or point.model == '' then
                        addError(errors, "world transformer '%s' needs a non-empty expected model name", logicalId)
                    end
                end
            elseif point.type == 'substation' then
                local substation = Substations[logicalId]
                if not substation then
                    addError(errors, "world point '%s' references unknown substation", logicalId)
                else
                    if point.substationId ~= logicalId then
                        addError(errors, "world substation '%s' has mismatched substationId", logicalId)
                    end
                    if point.gridId ~= substation.gridId then
                        addError(errors, "world substation '%s' has wrong gridId '%s'", logicalId, tostring(point.gridId))
                    end
                end
            end

            if type(point.expectedDistricts) ~= 'table' or #point.expectedDistricts == 0 then
                addError(errors, "world point '%s' needs expectedDistricts", logicalId)
            else
                local seenDistricts = {}
                for _, district in ipairs(point.expectedDistricts) do
                    if seenDistricts[district] then
                        addError(errors, "world point '%s' repeats expected district '%s'", logicalId, tostring(district))
                    end
                    seenDistricts[district] = true
                    if not Districts.Exists(district) then
                        addError(errors, "world point '%s' references unknown expected district '%s'", logicalId, tostring(district))
                    end
                end
            end
        end
    end

    for substationId in pairs(Substations) do
        if not expectedIds[substationId] then
            addError(errors, "substation '%s' has no world placement", substationId)
        end
    end
    for transformerId in pairs(Transformers) do
        if not expectedIds[transformerId] then
            addError(errors, "transformer '%s' has no world placement", transformerId)
        end
    end
end

function Validators.ValidateAll()
    local errors = {}
    local warnings = {}

    validateTopology(errors)
    validatePowerPolicies(errors)
    validateVisualProfiles(errors)
    validateCustomZones(errors)
    validateDistrictRegistry(errors, warnings)
    validateFeederTopology(errors, warnings)
    validateWorldPlacement(errors)
    validateRandomFailure(errors)
    validateDebug(errors)
    validateSecurity(errors)
    validateMetrics(errors)

    return #errors == 0, errors, warnings
end
