--[[
    server/transformer_manager.lua

    Runtime transformer state (spec §13). STATE and CONDITION are tracked
    and mutated independently — a transformer can be
    { state = ONLINE, condition = MODERATE_DAMAGE, damage = 38 } (spec
    §13 example): being damaged does not, by itself, cut power.

    State transitions go through an EXPLICIT adjacency table. An illegal
    transition (e.g. OFFLINE -> ONLINE directly, skipping RECOVERING) is
    rejected and logged (Constants.LogEvent.STATE_TRANSITION_REJECTED)
    rather than silently allowed — this is the RULE 4-style "don't assume,
    verify" discipline applied to our own state machine, not just to
    undocumented natives.

    No persistence here (Phase 14) — SetDamage/SetState only mutate the
    in-memory cache built by Init() from the static shared/grids.lua
    topology.
]]

TransformerManager = {}

local runtime = {} -- [transformerId] = Types.NewTransformer(...) instance

-- Legal state transitions. Reflexive edges (state -> itself) are always
-- allowed regardless of this table (see isTransitionAllowed) since
-- re-asserting the current state is a no-op, not a state change.
local ALLOWED_TRANSITIONS = {
    [Constants.TransformerState.ONLINE] = {
        [Constants.TransformerState.DEGRADED] = true,
        [Constants.TransformerState.OFFLINE] = true,
    },
    [Constants.TransformerState.DEGRADED] = {
        [Constants.TransformerState.ONLINE] = true,
        [Constants.TransformerState.OFFLINE] = true,
    },
    [Constants.TransformerState.OFFLINE] = {
        [Constants.TransformerState.REPAIRING] = true,
    },
    [Constants.TransformerState.REPAIRING] = {
        [Constants.TransformerState.RECOVERING] = true,
        [Constants.TransformerState.OFFLINE] = true, -- repair abandoned/failed
    },
    [Constants.TransformerState.RECOVERING] = {
        [Constants.TransformerState.ONLINE] = true,
        [Constants.TransformerState.COOLDOWN] = true,
    },
    [Constants.TransformerState.COOLDOWN] = {
        [Constants.TransformerState.ONLINE] = true,
    },
}

local function isTransitionAllowed(from, to)
    if from == to then return true end
    local edges = ALLOWED_TRANSITIONS[from]
    return edges ~= nil and edges[to] == true
end

local function inferIncidentCause(reason, opts)
    if opts and opts.incidentCause then return opts.incidentCause end
    local text = string.upper(tostring(reason or ''))
    if text:find('SABOTAGE', 1, true) then return Constants.IncidentCause.SABOTAGE end
    if text:find('ADMIN', 1, true) then return Constants.IncidentCause.ADMIN end
    return Constants.IncidentCause.SCRIPT
end

local function createTransformerIncident(id, reason, opts)
    if not IncidentManager then return end
    opts = opts or {}

    local ok, incidentIdOrRecord, err = pcall(IncidentManager.CreateIncident, {
        targetType = Constants.ComponentType.TRANSFORMER,
        targetId = id,
        cause = inferIncidentCause(reason, opts),
        severity = opts.incidentSeverity or 100,
        startedBy = opts.incidentSource or reason or 'SYSTEM',
        metadata = {
            failureReason = reason or 'unspecified',
        },
    })

    if not ok then
        Log.warn('transformer incident creation failed', {
            transformer = id,
            error = tostring(incidentIdOrRecord),
        })
    elseif not incidentIdOrRecord and err then
        Log.warn('transformer incident rejected', {
            transformer = id,
            error = tostring(err),
        })
    end
end

function TransformerManager.Init()
    runtime = {}
    for id in pairs(Transformers) do
        runtime[id] = Types.NewTransformer(id, { updatedAt = os.time(), revision = 0 })
    end
end

-- Restore a persisted row at boot (Phase 14, spec §47). Sets the record
-- directly — bypasses SetState's transition table entirely (this is
-- initialization, not a transition; there is no "from" state to
-- validate against) and does NOT call Persistence.SaveTransformer (would
-- just write back the row we just read) or fire the ONLINE incident-
-- resolve hook (restoring an already-ACTIVE incident's transformer back
-- to a persisted ONLINE state must not spuriously resolve it — incidents
-- are restored separately via IncidentManager.RestoreIncident).
function TransformerManager.RestoreState(row)
    local rec = runtime[row.transformer_id]
    if not rec then return end -- unknown transformer id in DB (topology changed since) — ignore

    rec.state = row.state or rec.state
    rec.condition = row.condition or rec.condition
    rec.damage = row.damage or rec.damage
    rec.lastFailure = row.last_failure
    rec.lastRepair = row.last_repair
    rec.updatedAt = row.updated_at or os.time()
    -- Revision is runtime-only. The transformer SQL table has no revision
    -- column; interaction sessions receive the fresh runtime revision after
    -- every boot instead of restoring a value that was never persisted.
    rec.revision = rec.revision or 0
end

function TransformerManager.Exists(id)
    return runtime[id] ~= nil
end

-- Returns a shallow copy — callers (debug commands, API exports) must not
-- mutate the internal cache directly.
function TransformerManager.GetState(id)
    local rec = runtime[id]
    return rec and Utils.ShallowCopy(rec) or nil
end

function TransformerManager.GetAllIds()
    local ids = {}
    for id in pairs(runtime) do
        ids[#ids + 1] = id
    end
    return ids
end

-- Core state mutator. `opts.force = true` bypasses the transition table —
-- used only by SetDamage() when a DESTROYED condition must force OFFLINE
-- from any state (a real transformer doesn't ask permission before it
-- explodes). Returns (ok: boolean, error: string?).
function TransformerManager.SetState(id, newState, reason, opts)
    opts = opts or {}
    local rec = runtime[id]
    if not rec then
        return false, ('unknown transformer "%s"'):format(tostring(id))
    end

    if not Constants.TransformerState[newState] then
        return false, ('invalid target state "%s"'):format(tostring(newState))
    end

    local fromState = rec.state
    if fromState == newState then
        if newState == Constants.TransformerState.OFFLINE then
            createTransformerIncident(id, reason, opts)
        end
        return true -- reflexive, no-op
    end

    if not opts.force and not isTransitionAllowed(fromState, newState) then
        Log.event(Constants.LogEvent.STATE_TRANSITION_REJECTED, {
            transformer = id, from = fromState, to = newState, reason = reason,
        })
        return false, ('illegal transition %s -> %s'):format(fromState, newState)
    end

    rec.state = newState
    rec.updatedAt = os.time()
    rec.revision = (rec.revision or 0) + 1

    if newState == Constants.TransformerState.OFFLINE then
        rec.lastFailure = os.time()
        Log.event(Constants.LogEvent.TRANSFORMER_OFFLINE, { transformer = id, reason = reason })
        createTransformerIncident(id, reason, opts)
    elseif newState == Constants.TransformerState.ONLINE and fromState ~= Constants.TransformerState.ONLINE then
        rec.lastRepair = os.time()
        Log.event(Constants.LogEvent.POWER_RESTORED, { transformer = id, reason = reason })

        -- Close the incident lifecycle loop (spec §17): whatever incident
        -- is still active for this transformer is now resolved. Without
        -- this, IncidentManager.UpdateStatus() would never be called by
        -- anything and every incident would stay ACTIVE forever — see
        -- Phase 11 redo notes. Forward reference to IncidentManager
        -- (loaded after this module, same pattern as the Replication
        -- forward reference below) — `reason` is passed as a diagnostic
        -- string, not a real player source; Phase 13's repair flow will
        -- pass the actual repairing player once that exists.
        if IncidentManager then
            local activeIncident = IncidentManager.GetActiveIncidentForTransformer(id)
            if activeIncident then
                IncidentManager.UpdateStatus(activeIncident.incidentId, Constants.IncidentStatus.RESOLVED, reason)
            end
        end
    end

    -- Any state change can flip grid/feeder/district power — recalculate
    -- everything this transformer can affect (Phase 18: grid, its feeder,
    -- and the districts that feeder supplies — see server/replication.lua's
    -- RecalculateForTransformer). Replication is loaded after this module
    -- (see fxmanifest.lua ordering) but this function is only ever CALLED
    -- after full startup, so the forward reference resolves fine at call
    -- time.
    if Replication then
        Replication.RecalculateForTransformer(id, reason)
    end

    -- Persist the state transition (Phase 14, spec §46: write on
    -- meaningful change only — this IS one). No-op if oxmysql isn't
    -- running (see server/persistence.lua's header note).
    if Persistence then
        Persistence.SaveTransformer(rec)
    end

    return true
end

-- Sets damage (0-100), re-derives condition, and forces OFFLINE if the
-- resulting condition reaches Config.OfflineAtCondition — regardless of
-- current operational state (spec §13-14).
function TransformerManager.SetDamage(id, damage, reason, context)
    local rec = runtime[id]
    if not rec then
        return false, ('unknown transformer "%s"'):format(tostring(id))
    end

    damage = Utils.Clamp(math.floor(damage + 0.5), 0, 100)
    local damageChanged = rec.damage ~= damage
    rec.damage = damage
    rec.condition = Utils.DamageToCondition(damage)
    rec.updatedAt = os.time()
    if damageChanged then
        rec.revision = (rec.revision or 0) + 1
    end

    Log.event(Constants.LogEvent.TRANSFORMER_DAMAGED, {
        transformer = id, damage = damage, condition = rec.condition, reason = reason,
    })

    if rec.condition == Config.OfflineAtCondition and rec.state ~= Constants.TransformerState.OFFLINE then
        local opts = { force = true }
        if context then
            opts.incidentCause = context.cause
            opts.incidentSource = context.source
            opts.incidentSeverity = context.severity or damage
        end
        TransformerManager.SetState(id, Constants.TransformerState.OFFLINE, 'condition:' .. rec.condition, opts)
        -- SetState's own Persistence.SaveTransformer call above already
        -- covers this record (damage was set on the SAME `rec` table
        -- just before this branch runs), no separate save needed here.
    else
        -- Damage alone doesn't guarantee a state change, but the grid's
        -- reported `level` can still shift for DEGRADED transformers
        -- contributing partial capacity — recalculate either way (grid +
        -- feeder + affected districts, see RecalculateForTransformer).
        if Replication then
            Replication.RecalculateForTransformer(id, reason)
        end

        if Persistence then
            Persistence.SaveTransformer(rec)
        end
    end

    return true
end
