# gnsh-blackout — City Infrastructure Power Grid Framework

Server-authoritative electricity grid, GTA-native-district geography, and a
gameplay-state-independent visual blackout layer for FiveM/QBCore. Built
from `CITY INFRASTRUCTURE (1).md` (Master Specification V3).

**Current status: Phase 1-25 live-accepted; Phase 26-35 release-candidate
implementation is present, with final live acceptance still pending.** See
`CHANGELOG.md` for what shipped in each phase
and what's deliberately deferred. The spec was updated mid-project (V3) to
retarget the project from a single-district MVP to a citywide framework —
**"Sandy is no longer the project scope, it's the first validated
district."** Repair, persistence, blackout/recovery flicker transitions,
visual ownership, the full ~84-code GTA district registry, and a real
GRID → SUBSTATION → FEEDER → TRANSFORMER → DISTRICT topology are all
implemented. Two grids run simultaneously today (`blaine_south` covering
Sandy Shores, and `ls_central` covering Downtown/Pillbox Hill/Mission Row)
— see `docs/MIGRATION_AUDIT.md` for the migration audit and `CHANGELOG.md`'s
Phase 18 section for the feeder-layer details.

## What works right now

- Multiple server-authoritative power grids running simultaneously
  (`blaine_south` — Sandy Shores/Harmony/Grand Senora Desert;
  `ls_central` — Downtown/Pillbox Hill/Mission Row), each with their own
  substations, feeders, and transformers. A district's power is computed
  from whichever feeder(s) actually supply it — two districts under the
  same grid can be in different states at once (see `shared/feeders.lua`).
- District detection via the GTA native `GetNameOfZone` (client) with an
  approximate AABB fallback for server-side lookups (see
  `shared/districts.lua`).
- Custom polygon/radius zones as an override layer (`Config.Zones`).
- Explicit transformer state machine (ONLINE/DEGRADED/OFFLINE/REPAIRING/
  RECOVERING/COOLDOWN) with a separate damage/condition model.
- Four power policies: PRIMARY, ANY, ALL, REQUIRED_COUNT.
- Granular StateBag replication with a monotonic revision counter.
- `IsPositionPowered` / `IsGridPowered` / `IsDistrictPowered` and friends,
  exported both server- and client-side.
- A native-artificial-lights "district client gate" visual layer for
  Sandy Shores, idempotent, reversible, and safe against visual failures
  (a broken adapter can never flip the logical grid back online).
- Sabotage (Termit/C4, ox_lib skillCheck + menuv multi-option menu) and a
  multi-stage repair flow (DIAGNOSE→...→RECONNECT_POWER, ox_lib
  progressBar, real `fuse`/`wiring_kit`/`control_module` items) — both
  server-authoritative via `server/interaction_manager.lua`'s session
  system.
- An incident lifecycle (create → resolve, spec §17) that actually
  closes — resolved automatically when a transformer reaches ONLINE.
- Generic district-level replication: `gridId`, `feederIds`,
  `sourceFeederId`, `powered`, `level`, `status`, `revision`, and optional
  `blockedBy` are published per district. Unassigned districts fail open.
- Parent failure propagation (Phase 21): admin-controlled GRID → SUBSTATION
  → FEEDER overrides block effective power without mutating child
  transformer state; parent restore exposes the child's real state again.
- World placement registry (Phase 22): physical transformer/substation
  coordinates, logical IDs, expected models, interaction radii and topology
  links live in `shared/world_placement.lua`; no network entity ID or
  automatic prop spawn is used.
- Topology-level incident impact (Phase 23): transformer, feeder, substation
  and grid failures share one lifecycle; active incident metadata includes
  target, feeder, affected districts, estimated impact and approximate
  location. An optional dispatch bridge emits `infra:dispatchIncident` without
  requiring a dispatch resource.
- External Power API (Phase 24): feeder/substation booleans, detached feeder
  state, district power paths, infrastructure-at-position lookup, affected
  district lookup and active incident snapshots. Unknown IDs return
  `nil, error`; recognized but unmanaged districts and unmapped positions
  fail open.
- Random Failure (Phase 25): disabled-by-default server scheduler with
  player gate, deterministic transformer destruction, topology impact checks,
  affected-district limit, global cooldown, injectable test providers, and
  optional feeder/substation weights (default zero).
- Security hardening (Phase 26): centralized source, target, distance,
  session, revision, rate-limit and ACE validation at server boundaries.
- Bounded server/client metrics (Phase 27): opt-in rolling counters and
  samples for recalc, replication, database, network and visual operations.
- Visual profile resolution (Phase 28): district profile first, then grid
  profile, then `NATIVE_CLIENT_GATE`; hybrid adapters are optional fallbacks.
- Explicit admin operations (Phase 30): restore/create/resolve/reload/resync
  commands use typed IDs and structured audit logging.
- Restart/resync contracts (Phase 31): persistence restore precedes grid and
  district publication; visual resync is client-only and idempotent.
- SQL persistence (`oxmysql` hard dependency): transformer/incident state and
  parent component overrides survive a restart when the additive schema table
  is imported.
- Debug commands: `/showdistrict`, `/districtaudit`, `/districtauditauto`,
  `/districtauditreport`, `/districtregistry`, `/griddebug`,
  `/showtransformers`, `/showincidents`, `/showinfrastructure`, `/powerdebug`, `/repairdebug`,
  `/visualprofile`, `/reloadvisual`, `/testtransition`, `/visualdebug`
  (client), `/setgridpower`, `/setdamage`, `/forcerepair`, `/giveitem`,
  `/showfeeders`, `/showsubstations`, `/showdistrictpower`, `/powerpath`,
  `/topologyaudit`, `/setgridstate`, `/setsubstationstate`, `/setfeederstate`
  (server, admin-gated where they mutate state), `/repairall` (admin-only
  test reset for all infrastructure).

## Architecture

Two independent domains, per the spec's central rule: the **Logical Power
Domain** (server-authoritative grid/substation/transformer/district state)
never depends on the **Visual Power Domain** (native lights, future
overlays/model swaps/PTFX). A broken visual adapter can log a failure; it
can never make `SANDY.powered` true again.

```
config.lua, shared/*.lua   -- static topology + tunables, both sides
bridge/*                    -- framework/inventory/target adapters, auto-detected
server/*                    -- grid/transformer/replication/API (source of truth)
client/*                    -- district polling, StateBag consumption, visual gating
profiles/*                  -- per-grid visual profile definitions
tests/*                     -- framework-free unit tests for the pure-Lua pieces
```

## Known limitation: district AABBs are approximate

`GetNameOfZone` is client-only. There is no server-side equivalent, but
`IsPositionPowered(coords)` must be callable from the server. The
workaround (`shared/districts.lua`) is an axis-aligned bounding box per
GTA district, sized from general knowledge of the map layout — **not**
extracted from game files, and not guaranteed pixel-accurate at borders.

Run `/districtaudit` while standing at any location you care about (and
especially at district borders) to compare the client's authoritative
`GetNameOfZone` result against the server's AABB result. A mismatch is
logged as `DISTRICT_AUDIT_MISMATCH` — tighten the relevant box in
`shared/districts.lua` until it clears. Don't ship server-side district
logic you haven't audited for the districts that matter to your server.

## Config

See `config.lua` for the full set of tunables (bridge detection, district
poll/hysteresis timing, resolver priority, power model thresholds).
Topology (grids/substations/transformers) lives in `shared/grids.lua`;
district codes/labels/AABBs in `shared/districts.lua`; physical placement
lives in `shared/world_placement.lua`.

Security is enabled by default. `Config.Security` controls source/session
validation, string limits, event rate windows and maximum session lifetime.
`Config.Metrics.enabled` is false by default; enable it temporarily when
profiling and keep its bounded `maxSamples` limit. Debug/read-only tooling is
off by default via `Config.Debug.enabled`; production admin operations remain
available through ACE validation. The resource explicitly requires `ox_lib`,
`menuv`, `ox_inventory` and `oxmysql` because their Lua entry points are
imported directly. QBCore, qb-target, dispatch and external consumers remain
soft integrations with runtime fallbacks.

## Debug quick start

The legacy debug tools are opt-in. For a temporary diagnostic session, set
`setr gnsh_blackout_debug true` in `server.cfg` and restart the resource; remove
the convar or set it to `false` after diagnostics. The production admin
gateway commands are explicit:

```
/setgridpower blaine_south 0    -- force Sandy's grid offline
/griddebug blaine_south         -- server console: full topology + state dump
/showdistrict                   -- client: current district/grid
/setgridpower blaine_south 1    -- restore

/setfeederstate blaine_south_feed_a OFFLINE -- parent failure test
/showfeeders blaine_south
/setfeederstate blaine_south_feed_a ONLINE

/showinfrastructure              -- server static + client runtime placement audit
/showinfrastructure sandy_tr_01 -- inspect one logical placement

/apiquery feeder blaine_south_feed_a
/apiquery path SANDY
/apiquery position 1961.0 3745.0 32.5
/apiquery affected feeder blaine_south_feed_a
/apiquery incidents

/restoretransformer <transformerId>
/restorefeeder <feederId>
/restoresubstation <substationId>
/restoregrid <gridId>
/createincident <targetType> <targetId>
/resolveincident <incidentId>
/reloadtopology
/resyncvisual [playerId|all]
/repairall                     -- admin test reset: damage, repairs, parents, incidents
```

## External Power API

Server exports are available from other resources through
`exports['gnsh-blackout']`. Existing grid/district/position exports remain
available. Boolean calls return `boolean` for a known target and
`nil, error` for an unknown ID:

```lua
local feederOnline, err = exports['gnsh-blackout']:IsFeederPowered('blaine_south_feed_a')
local substationOnline, err = exports['gnsh-blackout']:IsSubstationPowered('sandy_substation_01')
local feederState, err = exports['gnsh-blackout']:GetFeederState('blaine_south_feed_a')
local path, err = exports['gnsh-blackout']:GetPowerPathForDistrict('SANDY')
local location, err = exports['gnsh-blackout']:GetInfrastructureAtPosition(vector3(1961.0, 3745.0, 32.5))
local affected, err = exports['gnsh-blackout']:GetAffectedDistricts('feeder', 'blaine_south_feed_a')
local incidents = exports['gnsh-blackout']:GetActiveIncidents()
```

`GetPowerPathForDistrict` returns the district's grid → substation → feeder
→ transformer chain and preserves `powered`, `level`, `status`, `revision`,
`sourceFeederId` and `blockedBy`. `GetInfrastructureAtPosition` uses the
server district/AABB resolver for topology decisions; coordinates that do
not map to a known topology fail open with `powered=true, managed=false`.
Returned tables are recursive copies. Mutating a result cannot mutate the
resource's runtime state. `/apiquery` is read-only and requires the configured
admin ACE for player sources (server console source 0 is allowed).

## Persistence

Transformer/incident/parent-override state persists across `restart`/server
reboot.
`oxmysql` is a hard `dependency` (like `ox_lib`/`menuv`/`ox_inventory`) —
`server/persistence.lua` imports `@oxmysql/lib/MySQL.lua` (oxmysql's own
official Lua wrapper) rather than guessing its raw export calling
convention, which is what a soft-dependency first attempt got wrong (see
that file's header note: writes silently went nowhere, a restart
brought power back instead of preserving a blackout). `Persistence.
Available()` still checks `GetResourceState('oxmysql')` at runtime as a
defensive belt — if oxmysql is somehow stopped after boot, saves/loads
no-op instead of erroring.

To enable it:

1. Import `sql/schema.sql` into your server's database (three tables:
   `infrastructure_transformers`, `infrastructure_incidents`, and additive
   `infrastructure_component_overrides`). Existing tables are not dropped.
2. Make sure `oxmysql` is started before `gnsh-blackout` (already the
   case if you're running qb-core, which requires it).
3. That's it — no config toggle. `Persistence.Available()` auto-detects.

Writes are fire-and-forget (not awaited) from hot paths so a slow query
never blocks grid/transformer logic; only the boot-time load is awaited.

## Tests

`tests/` contains framework-free Lua unit tests for the pieces that don't
touch FiveM natives (damage model, power policy truth table, validators,
zone geometry). Run with a plain Lua 5.4 interpreter:

```
lua5.4 tests/run.lua
```

If no local Lua interpreter is available, leave the unit-test checkbox
unchecked and use the live acceptance commands documented in `CHANGELOG.md`;
the production resource does not load `tests/run.lua` as an in-game command.

## Extending to a new district/grid

1. Add any missing district codes to `shared/districts.lua` (label +
   approximate AABB).
2. Add the grid/substation/transformer topology to `shared/grids.lua`.
3. Add a visual profile in `profiles/<name>.lua` and list it in
   `fxmanifest.lua`'s `shared_scripts` (before `shared/validators.lua`).
4. Restart the resource — `shared/validators.lua` will refuse to start if
   any reference is broken, with a specific error per problem.

## Random Failure (Phase 25)

Automatic failures are disabled by default. Enable only after live acceptance:

```lua
Config.RandomFailure.enabled = true
```

Default behavior requires at least one online player. Transformer candidates
receive `damage = 100`, creating a `RANDOM_FAILURE` incident and reusing the
existing persistence, replication, repair, and recovery lifecycle. Feeder and
substation selection is implemented but disabled by their default weights.

Relevant settings:

```lua
Config.RandomFailure = {
    enabled = false,
    tickSec = 60,
    transformerWeight = 1.0,
    feederWeight = 0.0,
    substationWeight = 0.0,
    maxAutomaticOfflineDistricts = 6,
    cooldownSec = 300,
}
```

Live acceptance results are recorded in `CHANGELOG.md`; this README keeps the
configuration contract only.
