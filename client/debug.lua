--[[
    client/debug.lua

    Client-side debug commands (spec §63). This file starts with the
    Phase 2 commands (/showdistrict, /districtaudit) and gains the
    remaining ones (/griddebug, /visualprofile, /reloadvisual) once the
    modules they depend on exist (Phase 7-8) — see the additions further
    down, appended in the same phased order as the plan.
]]

if not Config.IsDebugEnabled() then return end

RegisterCommand('showdistrict', function()
    local label = ClientState.CurrentDistrict and Districts.GetLabel(ClientState.CurrentDistrict) or 'bilinmiyor'
    print(('[gnsh-blackout] District: %s (%s)  Grid: %s  Commits: %d'):format(
        ClientState.CurrentDistrict or 'nil',
        label,
        ClientState.CurrentGrid or 'nil',
        ClientState._districtCommitCount
    ))
end, false)

-- Compares the client's authoritative native-based district resolution
-- against the server's AABB approximation for the CURRENT position, and
-- logs a DISTRICT_AUDIT_MISMATCH if they disagree. This is the intended
-- calibration tool for shared/districts.lua's approximate AABB table —
-- see that file's header comment.
--
-- Phase 17: results are also accumulated into `auditResults` (below) so
-- /districtauditreport can summarize a whole session's worth of crossings
-- in one pass instead of reading one console line per border crossed.
local auditResults = {} -- [clientDistrict] = { serverDistrict = , match = , checkedAt = }
local autoAuditEnabled = false

local function runDistrictAudit()
    local coords = GetEntityCoords(PlayerPedId())
    local clientDistrict = ClientZone.ResolveDistrict(coords)
    if Metrics then Metrics.Inc('client.networkEvent.server') end
    TriggerServerEvent('gnsh-blackout:server:districtAudit', coords, clientDistrict)
end

RegisterCommand('districtaudit', runDistrictAudit, false)

RegisterNetEvent('gnsh-blackout:client:districtAuditResult', function(clientDistrict, serverDistrict, match)
    auditResults[clientDistrict] = { serverDistrict = serverDistrict, match = match, checkedAt = GetGameTimer() }

    if match then
        print(('^2[gnsh-blackout] districtaudit: MATCH — client=%s server=%s^7'):format(clientDistrict, serverDistrict or 'nil'))
    else
        print(('^1[gnsh-blackout] districtaudit: MISMATCH — client=%s server=%s (tighten the AABB in shared/districts.lua)^7'):format(clientDistrict, serverDistrict or 'nil'))
    end
end)

-- ── Phase 17 additions ───────────────────────────────────────────────────

-- Toggles automatic auditing: every time the player commits into a NEW
-- district (spec §5) that hasn't been checked yet this session, an audit
-- fires on its own — no need to remember to type /districtaudit at every
-- border. This is how the ~84-entry registry's AABB table is meant to get
-- calibrated over real play sessions rather than one manual check at a
-- time (see shared/districts.lua's header comment).
RegisterCommand('districtauditauto', function()
    autoAuditEnabled = not autoAuditEnabled
    print(('[gnsh-blackout] districtauditauto: %s'):format(autoAuditEnabled and 'ON' or 'OFF'))
end, false)

AddEventHandler('infra:districtChanged', function(newDistrict)
    if not autoAuditEnabled then return end
    if not newDistrict or newDistrict == Districts.UNKNOWN_CODE then return end
    if auditResults[newDistrict] then return end -- already checked this session
    runDistrictAudit()
end)

-- Summarizes every /districtaudit (manual or auto) result collected this
-- session — the "one pass instead of one line per crossing" tool the plan
-- calls for.
RegisterCommand('districtauditreport', function()
    local codes = {}
    for code in pairs(auditResults) do codes[#codes + 1] = code end
    table.sort(codes)

    print(('[gnsh-blackout] ── District Audit Report (%d checked) ──'):format(#codes))
    if #codes == 0 then
        print('  Hiç kontrol yapılmadı. /districtaudit veya /districtauditauto kullanın.')
        return
    end

    local mismatchCount = 0
    for _, code in ipairs(codes) do
        local r = auditResults[code]
        if r.match then
            print(('  ✓ %s'):format(code))
        else
            mismatchCount = mismatchCount + 1
            print(('  ✗ %s  (server resolved: %s)'):format(code, r.serverDistrict or 'nil'))
        end
    end
    print(('  Toplam: %d, Uyuşmayan: %d'):format(#codes, mismatchCount))
end, false)

-- Snapshot of the district registry itself (spec §17, not a live audit) —
-- counts by enabled/assigned/unassigned/unknown and category, so a
-- registry change can be sanity-checked without counting table entries by
-- hand.
RegisterCommand('districtregistry', function()
    local total, enabled, assigned, unassigned = 0, 0, 0, 0
    local byCategory = {}

    for code, entry in pairs(Districts.ByCode) do
        total = total + 1
        if entry.enabled then
            enabled = enabled + 1
            local status = Districts.GetAssignment(code)
            if status == 'ASSIGNED' then
                assigned = assigned + 1
            else
                unassigned = unassigned + 1
            end
        end
        byCategory[entry.category] = (byCategory[entry.category] or 0) + 1
    end

    print(('[gnsh-blackout] ── District Registry (%d total) ──'):format(total))
    print(('  Enabled: %d   Disabled: %d'):format(enabled, total - enabled))
    print(('  Assigned: %d   Unassigned: %d'):format(assigned, unassigned))
    for category, count in pairs(byCategory) do
        print(('  %s: %d'):format(category, count))
    end

    if unassigned > 0 then
        print('  Unassigned districts:')
        for code, entry in pairs(Districts.ByCode) do
            if entry.enabled and Districts.GetAssignment(code) == 'UNASSIGNED' then
                print(('    - %s (%s)'):format(code, entry.label))
            end
        end
    end
end, false)

-- ── Phase 8 additions ────────────────────────────────────────────────────

-- Client-side view of spec §64's debug output. Substation/transformer/
-- incident detail is server-only knowledge (the client never receives raw
-- transformer records) — use the server console's /griddebug for that;
-- this prints everything a client actually has visibility into.
RegisterCommand('griddebug', function()
    local gridId = ClientState.CurrentGrid
    local district = ClientState.CurrentDistrict

    print('[gnsh-blackout] ── Client Grid Debug ──')
    print(('  Current GTA District: %s (%s)'):format(district or 'nil', district and Districts.GetLabel(district) or 'bilinmiyor'))
    print(('  Infrastructure Grid:  %s'):format(gridId or 'nil'))

    if gridId then
        local state = GlobalState[Constants.StateKey.GRID .. gridId]
        if state then
            print(('  Power:      %s'):format(state.powered and 'ON' or 'OFF'))
            print(('  Power Level: %.2f'):format(state.level))
            print(('  Status:     %s'):format(state.status))
            print(('  Revision:   %d'):format(state.revision))
        else
            print('  Power: unknown (no state published yet)')
        end
    end

    print(('  Visual Mode:     %s'):format(gridId and ClientState.ActiveProfiles[gridId] or 'none'))
    print(('  Native Blackout: %s'):format(ClientState.AppliedNativeBlackout and 'ACTIVE' or 'inactive'))
end, false)

RegisterCommand('visualprofile', function()
    local gridId = ClientState.CurrentGrid
    if not gridId then
        print('[gnsh-blackout] no current grid')
        return
    end
    local profileName = ClientState.ActiveProfiles[gridId]
    local profile = profileName and VisualProfiles[profileName]
    if not profile then
        print(('[gnsh-blackout] grid "%s" has no active visual profile'):format(gridId))
        return
    end
    print(('[gnsh-blackout] grid=%s profile=%s mode=%s nativeBlackout.enabled=%s'):format(
        gridId, profileName, profile.mode, tostring(profile.nativeBlackout and profile.nativeBlackout.enabled)))
end, false)

-- Forces the visual layer to re-evaluate against whatever is currently
-- published for the player's current district — a manual ForceSync (spec
-- §28) for when something looks visually out of sync with server state.
-- `instant = true`: this is a resync, not a genuine power event, so it
-- must snap rather than replay the Phase 15 transition sequence.
--
-- Phase 18: reads DISTRICT state (not grid state) and includes both
-- `districtId`/`gridId` in the payload, matching client/main.lua's
-- applyDistrictState() shape — client/visual/manager.lua now keys
-- ownership by districtId, so a payload without it would be ignored.
RegisterCommand('reloadvisual', function()
    local districtId = ClientState.CurrentDistrict
    local gridId = ClientState.CurrentGrid
    if not districtId then
        print('[gnsh-blackout] no current district to reload')
        return
    end
    local state = GlobalState[Constants.StateKey.DISTRICT .. districtId]
    if not state then
        print('[gnsh-blackout] no published state for current district')
        return
    end
    local payload = {}
    for k, v in pairs(state) do payload[k] = v end
    payload.gridId = gridId
    payload.districtId = districtId
    payload.instant = true
    TriggerEvent('infra:powerStateChanged', payload)
    if NativeBlackout then NativeBlackout.ForceSync() end
    print('[gnsh-blackout] visual layer reloaded from current published state')
end, false)

-- ── Phase 15 addition ────────────────────────────────────────────────────

-- Plays the current grid's blackout/recovery sequence WITHOUT touching a
-- real transformer — pure timing/visual tuning tool. Restores whatever
-- the native state actually was before the test once it's done, so this
-- can't leave a player stuck in a fake blackout.
RegisterCommand('testtransition', function(_source, args)
    local kind = args[1]
    if kind ~= 'blackout' and kind ~= 'recovery' then
        print('[gnsh-blackout] usage: testtransition <blackout|recovery>')
        return
    end

    local gridId = ClientState.CurrentGrid
    local profileName = gridId and ClientState.ActiveProfiles[gridId]
    local profile = profileName and VisualProfiles[profileName]
    if not profile then
        print('[gnsh-blackout] no active visual profile for current grid — stand in Sandy first')
        return
    end

    local wasApplied = NativeBlackout.IsApplied()
    local previewHoldMs = 3000
    local recoverySetupMs = 1000
    print(('[gnsh-blackout] playing %s sequence for profile "%s" (preview hold=%dms)...'):format(kind, profileName, previewHoldMs))

    local function restore()
        -- Keep the preview visible long enough for a human test. The
        -- production visual manager never uses this dev-only hold.
        Wait(previewHoldMs)
        print('[gnsh-blackout] testtransition done, restoring real state')
        Transition.ForceSync(wasApplied, profile.nativeBlackout and profile.nativeBlackout.affectVehicles)
    end

    CreateThread(function()
        -- A recovery preview started while the real state is powered has no
        -- visible work to do. Seed a temporary blackout first, then play the
        -- requested recovery sequence and restore the captured real state.
        if kind == 'recovery' and not wasApplied then
            Transition.ForceSync(true, profile.nativeBlackout and profile.nativeBlackout.affectVehicles)
            Wait(recoverySetupMs)
        end

        if kind == 'blackout' then
            Transition.PlayBlackout(profile, restore)
        else
            Transition.PlayRecovery(profile, restore)
        end
    end)
end, false)

-- ── Phase 16 addition ────────────────────────────────────────────────────

-- Dumps every visual asset's ownership state next to whether the
-- adapter itself reports the effect as applied — a mismatch between
-- these two IS the bug class Phase 16 exists to catch (an asset held by
-- 0 owners but the native still applied, or vice versa).
RegisterCommand('visualdebug', function()
    local assets = VisualOwnership.Debug()

    print('[gnsh-blackout] ── Visual Ownership Debug ──')
    if #assets == 0 then
        print('  (no assets currently held)')
    end
    for _, entry in ipairs(assets) do
        print(('  %s  refCount=%d  owners=[%s]'):format(entry.assetId, entry.refCount, table.concat(entry.owners, ', ')))
    end

    print(('  NativeBlackout.IsApplied(): %s'):format(tostring(NativeBlackout.IsApplied())))
end, false)

-- Phase 22 client half of /showinfrastructure. GTA model lookup and native
-- district resolution are client-only, so the server command delegates this
-- runtime portion to the invoking player without trusting the result for
-- gameplay decisions.
local function expectedDistrict(point, district)
    for _, expected in ipairs(point.expectedDistricts or {}) do
        if expected == district then return true end
    end
    return false
end

local function nearbyExpectedModel(point)
    if not point.model or not point.coords then return 'n/a' end

    local modelHash = point.model
    if type(modelHash) == 'string' then
        local hashOk, hash = pcall(GetHashKey, modelHash)
        if not hashOk then return 'error' end
        modelHash = hash
    end

    local ok, entity = pcall(GetClosestObjectOfType,
        point.coords.x, point.coords.y, point.coords.z,
        point.visualRadius,
        modelHash,
        false, false, false
    )
    if not ok then return 'error' end
    return entity and entity ~= 0 and 'YES' or 'NO'
end

local function printClientInfrastructurePoint(point, playerCoords, district)
    if not point or not point.coords then
        print('[gnsh-blackout] placement has no usable coordinates')
        return
    end

    local distance = Utils.Distance3D(playerCoords, point.coords)
    local inInteractionRange = distance <= point.interactionRadius
    local districtMatch = expectedDistrict(point, district)

    print(('[gnsh-blackout] %s client: distance=%.1f interaction=%s modelNearby=%s district=%s expectedDistrict=%s'):format(
        point.logicalId,
        distance,
        inInteractionRange and 'YES' or 'NO',
        nearbyExpectedModel(point),
        district or 'nil',
        districtMatch and 'YES' or 'NO'
    ))
end

RegisterNetEvent('gnsh-blackout:client:showInfrastructure', function(requestedId)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local district = ClientZone.ResolveDistrict(playerCoords)

    print('[gnsh-blackout] ── Client World Placement Audit ──')
    if requestedId then
        printClientInfrastructurePoint(InfrastructureWorld[requestedId], playerCoords, district)
        return
    end

    local ids = {}
    for logicalId in pairs(InfrastructureWorld or {}) do ids[#ids + 1] = logicalId end
    table.sort(ids)
    for _, logicalId in ipairs(ids) do
        printClientInfrastructurePoint(InfrastructureWorld[logicalId], playerCoords, district)
    end
end)
