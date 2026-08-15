# gnsh-blackout

## Universal City Infrastructure for FiveM

<code>gnsh-blackout</code> turns electricity into a first-class, server-authoritative
gameplay system for serious roleplay servers. It models a citywide power
network from grids and substations down to feeders, transformers and GTA
districts, then connects that model to sabotage, incidents, repairs, visual
blackouts and administrator operations.

The result is an infrastructure layer that can support emergency dispatch,
utility-company roleplay, city events, criminal gameplay and developer-facing
power integrations without forcing a single framework or UI provider.

> **Release channel:** <code>0.38.0-rc.2</code> — release-candidate code with the final
> multiplayer, SQL-import and physical-placement acceptance gates documented in
> [CHANGELOG.md](CHANGELOG.md).

## Product highlights

| Capability | What it delivers |
|---|---|
| Citywide topology | 90 native GTA district codes mapped across 11 logical grids, 11 substations, 22 feeders and 22 transformers. |
| Real gameplay loop | Sabotage, incident creation, staged repair, recovery and visual power transitions. |
| Operational control | ACE-gated admin commands and a GTA district operations NUI with regional blackout controls. |
| Universal integration | QBCore, Qbox, ESX Legacy and standalone framework adapters, plus optional inventory, target, UI and database bridges. |
| Production safety | Server-side validation, distance checks, session/revision checks, rate limits, audit events and fail-safe fallbacks. |
| Persistence | Optional <code>oxmysql</code> storage for transformers, incidents and component overrides, with an explicit in-memory fallback. |
| Developer API | Grid, substation, feeder, transformer, district, position, power-path and incident exports for other resources. |

## Why server owners use it

- Create meaningful utility, repair, sabotage and emergency-response gameplay.
- Run infrastructure events at grid, feeder, district or region scope.
- Keep the logical power state authoritative even when an optional visual or
  third-party adapter is unavailable.
- Add the resource to an existing QBCore, Qbox, ESX or standalone stack without
  rewriting the core gameplay modules.
- Expose power state to dispatch, ATM, CCTV, door-lock or custom resources
  through stable server exports and optional internal events.

## Feature set

### City infrastructure model

The power domain follows a clear hierarchy:

~~~text
GRID
  └─ SUBSTATION
      └─ FEEDER
          └─ TRANSFORMER
              └─ GTA DISTRICTS
~~~

- All 90 native district identifiers have explicit logical ownership.
- Parent failures propagate to the affected child infrastructure.
- Partial recovery is represented instead of collapsing every failure into a
  single global switch.
- The city operational region includes the mapped Los Santos boundary and
  Tataviam Mountains while topology ownership remains independent.
- New logical infrastructure can be added through data tables rather than
  rewriting gameplay code.
- Unverified world placements remain logical-only; the resource does not invent
  fake props or interaction points for missing coordinates.

### Sabotage, incidents and repair

- Server-authoritative sabotage sessions for configured items such as thermite
  and C4.
- Skillcheck and progress stages with anti-speedhack timing floors.
- Incident lifecycle with cause, severity, target, affected districts and
  resolution state.
- Repair sessions that validate player distance, session ownership, revision
  and damage/state transitions.
- Rollback/refund handling for partial repair failures.
- Cleanup on disconnect, timeout, resource stop and stale-session rejection.

### Visual blackout layer

- District-to-grid visual profile resolution.
- Native blackout effects with ownership and cleanup tracking.
- Transition handling for online, degraded and blackout states.
- Resource-owned NUI for sabotage, repair, notification, progress and
  skillcheck flows.
- Admin operations panel with district map, labels, hover/selection feedback,
  pan/zoom controls and regional actions.

The logical power domain never depends on the visual power domain: a visual
adapter failure cannot change the authoritative power decision.

### Universal bridge

The bridge detects compatible resources at runtime, validates adapter contracts
and switches to a safe fallback when a provider is unavailable.

| Category | Automatic adapters | Explicit values |
|---|---|---|
| Framework | Qbox, QBCore, ESX Legacy, standalone | <code>qbox</code>, <code>qbcore</code>, <code>esx</code>, <code>standalone</code> |
| Inventory | ox, qs, ps, qb, framework, none | <code>ox_inventory</code>, <code>qs_inventory</code>, <code>ps_inventory</code>, <code>qb_inventory</code>, <code>framework</code>, <code>none</code> |
| Target | ox, qb, qtarget, standalone | <code>ox_target</code>, <code>qb_target</code>, <code>qtarget</code>, <code>standalone</code>, <code>textui</code>, <code>none</code> |
| Notify | Resource NUI, framework, ox_lib, native | <code>nui</code>, <code>framework</code>, <code>ox_lib</code>, <code>internal</code> |
| Menu | Resource NUI, ox_lib, qb-menu, MenuV, native | <code>nui</code>, <code>ox_lib</code>, <code>qb_menu</code>, <code>menuv</code>, <code>internal</code> |
| Progress | Resource NUI, ox_lib, progressbar, native | <code>nui</code>, <code>ox_lib</code>, <code>progressbar</code>, <code>internal</code> |
| Skillcheck | Resource NUI, ox_lib, qb-lock, native | <code>nui</code>, <code>ox_lib</code>, <code>qb_lock</code>, <code>internal</code> |
| Database | oxmysql, memory | <code>oxmysql</code>, <code>memory</code> |

Legacy resource aliases are normalized. <code>/blackoutbridge</code> reports the
active providers, capabilities and fallback reasons. Adapter snapshots are
replaced atomically after resource start/stop, and target interactables are
rebound without duplicate zones.

## Compatibility and requirements

- FiveM artifact with <code>cerulean</code> support and Lua 5.4 enabled.
- QBCore, Qbox, ESX Legacy or no framework at all.
- Third-party integrations are optional at bridge level. Configure only the
  providers your server actually runs.
- <code>oxmysql</code> is required only when restart persistence is desired.
  Without it, the memory adapter keeps the current runtime operational but
  intentionally does not survive a restart.
- Import [sql/schema.sql](sql/schema.sql) before enabling SQL-backed persistence.

## Installation

1. Copy this resource to your server resources directory, for example:

   ~~~text
   resources/[standalone]/gnsh-blackout
   ~~~

2. Import [sql/schema.sql](sql/schema.sql) when using <code>oxmysql</code> persistence.
3. Start your selected framework, inventory, target and database resources
   before this resource when those integrations are enabled.
4. Add the resource to <code>server.cfg</code>:

   ~~~cfg
   ensure gnsh-blackout
   ~~~

5. Review <code>Config.Bridge</code>, security permissions and item settings in
   [config.lua](config.lua).
6. Give the resource a restart and review the bridge diagnostic output before
   opening the server to players.

No vendor UI is required for the core experience: the bundled NUI is the
default for gameplay-facing notify, menu, progress and skillcheck categories.

## Recommended configuration

The production-oriented default bridge keeps framework, inventory, target and
database detection automatic while pinning gameplay UI to the bundled NUI:

~~~lua
Config.Bridge = {
    framework = 'auto',
    inventory = 'auto',
    target = 'auto',
    notify = 'nui',
    menu = 'nui',
    progress = 'nui',
    skillcheck = 'nui',
    database = 'auto',
}
~~~

Important production switches:

| Setting | Default | Purpose |
|---|---:|---|
| <code>Config.Security.enabled</code> | <code>true</code> | Enables the central mutation gateway. |
| <code>Config.Debug.enabled</code> | <code>false</code> | Keeps diagnostic tooling off by default. |
| <code>Config.Metrics.enabled</code> | <code>false</code> | Enables bounded runtime metrics when needed. |
| <code>Config.RandomFailure.enabled</code> | <code>false</code> | Keeps automatic failures opt-in. |
| <code>Config.Sabotage.requireItem</code> | <code>true</code> | Requires the configured sabotage item. |
| <code>Config.Dispatch.enabled</code> | <code>true</code> | Keeps the internal dispatch event available; an external resource remains optional. |

Use explicit adapter values when multiple compatible resources are running and
you need deterministic provider selection.

## Admin operations

All mutation commands pass the server-side admin gateway and emit structured
audit events. The exact ACE setup belongs to the server owner; never rely on a
client event as an authorization decision.

### Infrastructure control

~~~text
/setgridstate <gridId> <ONLINE|OFFLINE>
/setsubstationstate <substationId> <ONLINE|OFFLINE>
/setfeederstate <feederId> <ONLINE|OFFLINE>
/restoregrid <gridId>
/restoresubstation <substationId>
/restorefeeder <feederId>
/restoretransformer <transformerId>
/createincident <targetType> <targetId>
/resolveincident <incidentId>
/repairall
~~~

### Operations and regional control

~~~text
/blackout_<region>
/restore_<region>
/reloadtopology
/resyncvisual [all|playerId]
/blackoutbridge
~~~

The regional commands resolve district membership directly and are independent
of transformer, feeder and assigned-grid ownership. The bundled admin NUI
exposes the same operations through the map-oriented operations surface.

## Developer API

Server exports currently include:

~~~text
IsGridPowered
IsDistrictPowered
IsPositionPowered
GetGridState
GetDistrictState
GetTransformerState
GetSubstationState
IsSubstationPowered
IsFeederPowered
GetFeederState
GetInfrastructureAtPosition
GetPowerPathForDistrict
GetAffectedDistricts
GetActiveIncident
GetIncident
GetActiveIncidents
GetAllActiveIncidents
~~~

Unknown explicit IDs return <code>nil, error</code>. Position and unmapped-district
queries follow the configured fail-open behavior rather than inventing a
blackout for an unrelated resource. The internal dispatch event is:

~~~text
infra:dispatchIncident
~~~

Optional dispatch, ATM, CCTV and door-lock consumers should treat the resource
as an integration provider and keep their own fallback behavior.

## Persistence and recovery

With <code>oxmysql</code> and the supplied schema, the resource persists:

- transformer state and damage;
- active and historical incident identifiers/state;
- parent grid, substation and feeder overrides.

The memory adapter is useful for development, demonstrations and servers that
do not need restart persistence. Its state is intentionally process-local. For
production deployments, follow [docs/DEPLOYMENT_BACKUP.md](docs/DEPLOYMENT_BACKUP.md),
[docs/ROLLBACK.md](docs/ROLLBACK.md) and
[docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md).

## Validation and release confidence

The repository includes framework-free Lua contracts for topology, power
policy, recovery, security, metrics, restart/resync, integration and bridge
behavior:

~~~bash
lua5.4 tests/run.lua
~~~

The current changelog records the latest topology suite and syntax-scan
results, plus the live acceptance gates that remain intentionally open. Read
[CHANGELOG.md](CHANGELOG.md) and
[docs/STAGING_TEST_MATRIX.md](docs/STAGING_TEST_MATRIX.md) before treating
this release candidate as production-closed.

## Extending the city

1. Add or update district registry and geometry data in
   <code>shared/districts.lua</code> and <code>shared/district_geometry.lua</code>.
2. Define grids, substations and transformers in <code>shared/grids.lua</code>.
3. Define feeder ownership in <code>shared/feeders.lua</code>.
4. Add visual profiles only when the corresponding assets and world placement
   are verified.
5. Run topology validation before live deployment.

The separation between data tables, bridge adapters, server authority and
client presentation is intentional: it keeps future topology expansion from
forcing a gameplay rewrite.

## Project documentation

- [CHANGELOG.md](CHANGELOG.md) — release history and acceptance status
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — domain and runtime design
- [docs/INTEGRATION_GUIDE.md](docs/INTEGRATION_GUIDE.md) — framework and
  consumer integration
- [docs/SECURITY.md](docs/SECURITY.md) — trust boundaries and validation
- [docs/OPERATIONS.md](docs/OPERATIONS.md) — operator runbook
- [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md) — release gate
- [docs/STAGING_TEST_MATRIX.md](docs/STAGING_TEST_MATRIX.md) — live test plan

## License

Review the distribution license before deployment. Deployment owners
are responsible for confirming the licensing terms of this resource and all
third-party assets used with it.
