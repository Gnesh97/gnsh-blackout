--[[
    server/replication.lua

    Granular GlobalState publication (spec §19) with a monotonic revision
    counter (spec §20). Deliberately NOT one giant
    `GlobalState.InfrastructureGrid` table — every grid, feeder, and
    district gets its own key so a client only re-evaluates what actually
    changed.

    Revision is a SINGLE server-wide counter, shared across grid/feeder/
    district keys. Phase 1-17 stamped a grid AND every district it feeds
    with the exact same revision number on every change (an "atomic
    group"). Phase 18 relaxes that: grid, feeder, and district recalculate
    (and diff/bump/publish) INDEPENDENTLY now, because a district's power
    is no longer a copy of its grid's — it's computed from whichever
    feeder(s) actually supply it (see PowerCalculator.CalculateDistrict).
    A single transformer failure can therefore produce two or three
    DIFFERENT revision numbers (grid, feeder, affected district) instead
    of one shared number. This is still safe: every key's own revision is
    still strictly monotonic from the same shared counter, which is all
    client/main.lua's stale-read guard (`value.revision <=
    ClientState.CurrentPowerRevision`) actually depends on — it compares a
    key's new revision against the client's own last-seen revision for
    THAT key, never across keys. The "exact same number" guarantee was a
    nice-to-have for reasoning about simultaneity, not a correctness
    requirement, and re-deriving it under independent recalculation would
    need a batched-transaction wrapper this phase doesn't add (documented
    simplification, see CHANGELOG Phase 18).

    Replication.Init() force-publishes the STARTING snapshot (revision 0)
    for every grid/feeder/district unconditionally. The Recalculate*()
    functions are the steady-state path: each is a no-op (no revision
    bump, no publish) if the freshly computed state is identical to
    what's already published — "no change, no write" (spec §46).
]]

Replication = {}

local gridStates = {}      -- [gridId] = Types.NewGridState(...) snapshot (last published)
local feederStates = {}    -- [feederId] = Types.NewFeederState(...) snapshot (last published)
local districtStates = {}  -- [district] = Types.NewDistrictState(...) snapshot (last published)
local revisionCounter = 0

local function sameBlockedBy(a, b)
    if a == b then return true end
    if not a or not b then return false end
    return a.type == b.type and a.id == b.id
end

local function sameList(a, b)
    if a == b then return true end
    if not a or not b or #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

local function copyList(list)
    local copy = {}
    for i, value in ipairs(list or {}) do copy[i] = value end
    return copy
end

local function buildTransformerList(gridId)
    local list = {}
    for _, trId in ipairs(GridManager.GetTransformersForGrid(gridId)) do
        local def = Transformers[trId]
        local rt = TransformerManager.GetState(trId)
        local blockedBy = FailureManager and FailureManager.GetBlockingAncestor(Constants.ComponentType.TRANSFORMER, trId)
        if def and rt then
            -- Parent failure is an effective OFFLINE input, not a reason to
            -- remove the transformer from the policy input. Keeping the
            -- child in the list preserves ALL/REQUIRED_COUNT semantics.
            list[#list + 1] = {
                id = trId,
                primary = def.primary == true,
                state = blockedBy and Constants.TransformerState.OFFLINE or rt.state,
            }
        end
    end
    return list
end

local function calculateGrid(gridId)
    local grid = Grids[gridId]
    if not grid then return nil end

    local blockedBy = FailureManager and FailureManager.GetBlockingAncestor(Constants.ComponentType.GRID, gridId)
    if blockedBy then
        return {
            powered = false,
            level = 0.0,
            status = Constants.GridStatus.BLACKOUT,
            blockedBy = blockedBy,
            forcedOffline = true,
        }
    end

    local result = PowerCalculator.Calculate(grid, buildTransformerList(gridId))
    result.forcedOffline = false
    return result
end

local function publishGrid(gridState)
    if Metrics then Metrics.Inc('server.stateBagWrite.grid') end
    GlobalState[Constants.StateKey.GRID .. gridState.gridId] = gridState
end

local function publishFeeder(feederState)
    if Metrics then Metrics.Inc('server.stateBagWrite.feeder') end
    GlobalState[Constants.StateKey.FEEDER .. feederState.feederId] = feederState
end

local function publishDistrict(districtState)
    if Metrics then Metrics.Inc('server.stateBagWrite.district') end
    GlobalState[Constants.StateKey.DISTRICT .. districtState.district] = districtState
end

local function fireChangeEvents(grid, gridId, old, new)
    local payload = {
        version = Constants.EVENT_VERSION,
        gridId = gridId,
        districts = grid.districts,
        powered = new.powered,
        level = new.level,
        status = new.status,
        revision = new.revision,
    }

    if old.powered and not new.powered then
        Log.event(Constants.LogEvent.GRID_POWER_LOST, { gridId = gridId, revision = new.revision })
        TriggerEvent('gnsh-blackout:powerLost', payload)
        if Metrics then Metrics.Inc('server.networkEvent.broadcast') end
        TriggerClientEvent('gnsh-blackout:powerLost', -1, payload)
    elseif not old.powered and new.powered then
        Log.event(Constants.LogEvent.POWER_RESTORED, { gridId = gridId, revision = new.revision })
        TriggerEvent('gnsh-blackout:powerRestored', payload)
        if Metrics then Metrics.Inc('server.networkEvent.broadcast') end
        TriggerClientEvent('gnsh-blackout:powerRestored', -1, payload)
    end

    if old.level ~= new.level then
        TriggerEvent('gnsh-blackout:powerLevelChanged', payload)
        if Metrics then Metrics.Inc('server.networkEvent.broadcast') end
        TriggerClientEvent('gnsh-blackout:powerLevelChanged', -1, payload)
    end
end

-- district -> its power state, computed from whichever feeder(s) actually
-- supply it (spec §18), falling back to its owning grid's CURRENT cached
-- state if no feeder covers it yet (Phase 1-17 behavior, preserved for
-- any district a grid claims but no feeder was wired up for — matches
-- shared/validators.lua's Config.Topology.warnUnassignedDistricts warning,
-- this is the actual runtime behavior that warning is describing).
local function computeDistrictState(districtCode)
    local feederIds = GridManager.GetFeedersForDistrict(districtCode)
    table.sort(feederIds)

    if #feederIds > 0 then
        local supply = {}
        for _, feederId in ipairs(feederIds) do
            local fs = FeederManager.GetState(feederId)
            if fs then supply[#supply + 1] = fs end
        end
        local result = PowerCalculator.CalculateDistrict(supply)
        result.feederIds = copyList(feederIds)
        result.sourceFeederId = result.sourceFeederId or feederIds[1]
        return result
    end

    local gridId = GridManager.GetGridForDistrict(districtCode)
    local gs = gridId and gridStates[gridId]
    if gs then
        return {
            powered = gs.powered,
            level = gs.level,
            status = gs.status,
            feederIds = {},
            sourceFeederId = nil,
            blockedBy = gs.blockedBy,
        }
    end

    -- No feeder AND no grid state cached yet — shouldn't normally happen
    -- (this is only called for districts a grid actually claims), but
    -- fail open rather than report a phantom blackout.
    return { powered = true, level = 1.0, status = Constants.GridStatus.ONLINE, feederIds = {} }
end

-- Initial startup publish (spec §47: "Publish Replicated State"). Always
-- writes, regardless of whether the computed state matches the
-- Types.New*State() defaults — otherwise a fresh "everything ONLINE"
-- startup would never actually populate GlobalState, and clients that
-- join before the first real change would see nothing.
function Replication.Init()
    gridStates = {}
    feederStates = {}
    districtStates = {}
    revisionCounter = 0

    for _, gridId in ipairs(GridManager.GetAllGridIds()) do
        local grid = Grids[gridId]
        local result = calculateGrid(gridId)

        local gridState = Types.NewGridState(gridId, {
            powered = result.powered, level = result.level, status = result.status,
            forcedOffline = result.forcedOffline == true, blockedBy = result.blockedBy,
            revision = revisionCounter,
        })
        gridStates[gridId] = gridState
        publishGrid(gridState)
    end

    for _, feederId in ipairs(GridManager.GetAllFeederIds()) do
        local fs = FeederManager.GetState(feederId)
        if fs then
            local feederState = Types.NewFeederState(feederId, {
                substationId = fs.substationId, powered = fs.powered, level = fs.level, status = fs.status,
                forcedOffline = fs.forcedOffline == true, blockedBy = fs.blockedBy,
                revision = revisionCounter,
            })
            feederStates[feederId] = feederState
            publishFeeder(feederState)
        end
    end

    -- Districts computed AFTER grids/feeders above are both populated —
    -- computeDistrictState() needs gridStates for its no-feeder fallback
    -- path and calls FeederManager.GetState() fresh for its feeder path.
    for _, gridId in ipairs(GridManager.GetAllGridIds()) do
        local grid = Grids[gridId]
        for _, code in ipairs(grid.districts) do
            local result = computeDistrictState(code)
            local districtState = Types.NewDistrictState(code, {
                gridId = gridId,
                feederIds = copyList(result.feederIds),
                sourceFeederId = result.sourceFeederId,
                powered = result.powered, level = result.level, status = result.status,
                blockedBy = result.blockedBy, revision = revisionCounter,
            })
            districtStates[code] = districtState
            publishDistrict(districtState)
        end
    end
end

-- Recompute a single grid's power state from its transformers' current
-- runtime state and publish if (and only if) it actually changed. No
-- longer touches districtStates (Phase 18 — see file header).
function Replication.RecalculateGrid(gridId, reason)
    if Metrics then Metrics.Inc('server.recalculate.grid') end
    local grid = Grids[gridId]
    if not grid then return end

    local old = gridStates[gridId]
    if not old then
        -- Init() hasn't run yet (or this grid was added after startup) —
        -- nothing to diff against, so there's nothing safe to do here.
        Log.warn('RecalculateGrid called before Replication.Init() established a baseline', { gridId = gridId })
        return
    end

    local result = calculateGrid(gridId)

    if old.powered == result.powered and old.level == result.level and old.status == result.status
        and old.forcedOffline == (result.forcedOffline == true)
        and sameBlockedBy(old.blockedBy, result.blockedBy) then
        return -- no change, no write (spec §46)
    end

    revisionCounter = revisionCounter + 1

    local newGridState = Types.NewGridState(gridId, {
        powered = result.powered, level = result.level, status = result.status,
        forcedOffline = result.forcedOffline == true, blockedBy = result.blockedBy,
        revision = revisionCounter,
    })
    gridStates[gridId] = newGridState
    publishGrid(newGridState)

    fireChangeEvents(grid, gridId, old, newGridState)

    Log.debug('grid recalculated', { gridId = gridId, powered = result.powered, status = result.status, reason = reason, revision = revisionCounter })
end

-- Recompute a single district's power state (Phase 18) and publish if it
-- changed. Safe to call for a district with no feeder coverage at all —
-- computeDistrictState() falls back to its grid's cached state, so this
-- degrades to Phase 1-17 behavior for any district not yet wired to a
-- feeder rather than erroring.
function Replication.RecalculateDistrict(districtCode, reason)
    if Metrics then Metrics.Inc('server.recalculate.district') end
    local old = districtStates[districtCode]
    if not old then
        Log.warn('RecalculateDistrict called before Replication.Init() established a baseline', { district = districtCode })
        return
    end

    local result = computeDistrictState(districtCode)

    local gridId = GridManager.GetGridForDistrict(districtCode)
    if old.powered == result.powered and old.level == result.level and old.status == result.status
        and old.gridId == gridId
        and old.sourceFeederId == result.sourceFeederId
        and sameList(old.feederIds, result.feederIds)
        and sameBlockedBy(old.blockedBy, result.blockedBy) then
        return
    end

    revisionCounter = revisionCounter + 1

    local newDistrictState = Types.NewDistrictState(districtCode, {
        gridId = gridId,
        feederIds = copyList(result.feederIds),
        sourceFeederId = result.sourceFeederId,
        powered = result.powered, level = result.level, status = result.status,
        blockedBy = result.blockedBy, revision = revisionCounter,
    })
    districtStates[districtCode] = newDistrictState
    publishDistrict(newDistrictState)

    Log.debug('district recalculated', { district = districtCode, powered = result.powered, status = result.status, reason = reason, revision = revisionCounter })
end

-- Recompute a single feeder's power state and publish if it changed, then
-- cascade into every district that feeder supplies (their aggregate may
-- have just changed too — spec §18, the whole point of the feeder layer).
function Replication.RecalculateFeeder(feederId, reason)
    if Metrics then Metrics.Inc('server.recalculate.feeder') end
    local feeder = Feeders[feederId]
    if not feeder then return end

    local old = feederStates[feederId]
    if not old then
        Log.warn('RecalculateFeeder called before Replication.Init() established a baseline', { feederId = feederId })
        return
    end

    local fs = FeederManager.GetState(feederId)
    if not fs then return end

    if old.powered ~= fs.powered or old.level ~= fs.level or old.status ~= fs.status
        or old.forcedOffline ~= (fs.forcedOffline == true)
        or not sameBlockedBy(old.blockedBy, fs.blockedBy) then
        revisionCounter = revisionCounter + 1

        local newFeederState = Types.NewFeederState(feederId, {
            substationId = fs.substationId, powered = fs.powered, level = fs.level, status = fs.status,
            forcedOffline = fs.forcedOffline == true, blockedBy = fs.blockedBy,
            revision = revisionCounter,
        })
        feederStates[feederId] = newFeederState
        publishFeeder(newFeederState)

        Log.debug('feeder recalculated', { feederId = feederId, powered = fs.powered, status = fs.status, reason = reason, revision = revisionCounter })
    end

    for _, code in ipairs(feeder.districts) do
        Replication.RecalculateDistrict(code, reason)
    end
end

local function recalculateGridFallbackDistricts(gridId, reason)
    local grid = Grids[gridId]
    if not grid then return end

    for _, districtCode in ipairs(grid.districts) do
        if #GridManager.GetFeedersForDistrict(districtCode) == 0 then
            Replication.RecalculateDistrict(districtCode, reason)
        end
    end
end

-- Single entry point server/transformer_manager.lua calls on every state/
-- damage mutation (spec §58 — only recalculates what this ONE
-- transformer can actually affect: its grid, its feeder if it has one,
-- and — via RecalculateFeeder — the districts that feeder supplies. A
-- transformer not yet wired to any feeder (shouldn't happen given
-- shared/feeders.lua covers every transformer today, but defensive)
-- falls back to recalculating its whole grid's districts directly,
-- exactly like Phase 1-17 did.
function Replication.RecalculateForTransformer(transformerId, reason)
    if Metrics then Metrics.Inc('server.recalculate.transformer') end
    local gridId = GridManager.GetGridForTransformer(transformerId)
    if gridId then
        Replication.RecalculateGrid(gridId, reason)
    end

    local feederId = GridManager.GetFeederForTransformer(transformerId)
    if feederId then
        Replication.RecalculateFeeder(feederId, reason)
    end
    recalculateGridFallbackDistricts(gridId, reason)
end

function Replication.RecalculateForFeeder(feederId, reason)
    if Metrics then Metrics.Inc('server.recalculate.forFeeder') end
    local gridId = GridManager.GetGridForSubstation(GridManager.GetSubstationForFeeder(feederId))
    if gridId then Replication.RecalculateGrid(gridId, reason) end
    Replication.RecalculateFeeder(feederId, reason)
    recalculateGridFallbackDistricts(gridId, reason)
end

function Replication.RecalculateForSubstation(substationId, reason)
    if Metrics then Metrics.Inc('server.recalculate.substation') end
    local gridId = GridManager.GetGridForSubstation(substationId)
    if gridId then Replication.RecalculateGrid(gridId, reason) end
    for _, feederId in ipairs(GridManager.GetFeedersForSubstation(substationId)) do
        Replication.RecalculateFeeder(feederId, reason)
    end
    recalculateGridFallbackDistricts(gridId, reason)
end

function Replication.RecalculateForGrid(gridId, reason)
    if Metrics then Metrics.Inc('server.recalculate.forGrid') end
    Replication.RecalculateGrid(gridId, reason)
    for _, feederId in ipairs(GridManager.GetAllFeederIds()) do
        local substationId = GridManager.GetSubstationForFeeder(feederId)
        if GridManager.GetGridForSubstation(substationId) == gridId then
            Replication.RecalculateFeeder(feederId, reason)
        end
    end

    recalculateGridFallbackDistricts(gridId, reason)
end

function Replication.GetGridState(gridId)
    local state = gridStates[gridId]
    return state and Utils.ShallowCopy(state) or nil
end

function Replication.GetFeederState(feederId)
    local state = feederStates[feederId]
    return state and Utils.ShallowCopy(state) or nil
end

function Replication.GetDistrictState(district)
    local state = districtStates[district]
    return state and Utils.ShallowCopy(state) or nil
end
