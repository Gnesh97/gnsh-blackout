# gnsh-blackout - Universal City Infrastructure

Server-authoritative electricity grid, GTA district geography, incident
lifecycle, sabotage, staged repair and visual blackout layer for FiveM.
Framework, inventory, target, UI and database resources are optional.

Current status: Phase 1-25 live-accepted. Universal bridge work is release
candidate code; final multiplayer, SQL import and public acceptance remain
release gates. See `CHANGELOG.md`.

## What works

- Multi-grid `GRID -> SUBSTATION -> FEEDER -> TRANSFORMER -> DISTRICT`
  topology with partial recovery and parent failure propagation.
- Citywide logical topology covers all 90 native district codes plus the
  synthetic HARMOSUB test zone across 11 grids, 11 substations, 22 feeders
  and 22 transformers. Unverified components remain logical-only until real
  world coordinates are supplied; no fake props or interaction points are
  created. The city operational region follows the mapped Los Santos boundary
  and includes Tataviam Mountains; topology ownership remains independent.
- Server-authoritative sabotage, incident impact, repair sessions, revisions,
  distance checks, rate limits and ACE-gated admin operations.
- Recursive state replication, late join/reconnect sync and visual cleanup.
- District profile -> grid profile -> `NATIVE_CLIENT_GATE` visual fallback.
- Phase 25 random failure scheduler, disabled by default, with player gate,
  district limit and cooldown.
- Resource-owned universal NUI for menu, notification, progress and skillcheck;
  no framework UI dependency. Internal routes forward to this UI; native is
  only the last-resort fallback.
- Optional oxmysql persistence; memory fallback keeps current runtime alive
  when SQL is absent.

## Architecture

The Logical Power Domain never depends on the Visual Power Domain. A visual
adapter failure cannot change logical power state.

```text
config.lua + shared/*       static topology and validation
bridge/*                    runtime adapters and internal fallback
server/*                    authoritative state, persistence and API
client/*                    district polling, replication and visuals
profiles/*                  district/grid visual profiles
tests/*                     framework-free Lua unit tests
```

## Compatibility matrix

| Category | Automatic adapters | Explicit values |
|---|---|---|
| Framework | qbx_core, qb-core, es_extended, standalone | `qbox`, `qbcore`, `esx`, `standalone` |
| Inventory | ox_inventory, qs-inventory, ps-inventory, qb-inventory, framework, none | `ox_inventory`, `qs_inventory`, `ps_inventory`, `qb_inventory`, `framework`, `none` |
| Target | ox_target, qb-target, qtarget, standalone | `ox_target`, `qb_target`, `qtarget`, `standalone`, `textui`, `none` |
| Notify | universal NUI, framework, ox_lib, native fallback | `nui`, `framework`, `ox_lib`, `internal` |
| Menu | universal NUI, ox_lib, qb-menu, MenuV, native fallback | `nui`, `ox_lib`, `qb_menu`, `menuv`, `internal` |
| Progress | universal NUI, ox_lib, progressbar, native fallback | `nui`, `ox_lib`, `progressbar`, `internal` |
| Skillcheck | universal NUI, ox_lib, qb-lock, native fallback | `nui`, `ox_lib`, `qb_lock`, `internal` |
| Database | oxmysql, memory | `oxmysql`, `memory` |

Legacy aliases (`qb-core`, `qb-inventory`, `qb-target`, `ox`) are normalized.
Missing explicit adapters fail safe to category fallback. `/blackoutbridge`
prints active adapters, capabilities and fallback reasons. Adapter snapshot is
replaced atomically after resource start/stop; registered target interactables
are rebound once, without duplicate zones.

Client UI categories are pinned to resource-owned `nui`, so sabotage and repair
look identical on QBCore, Qbox, ESX and standalone. Internal routes still
forward to the same UI when selected explicitly. Set a category to `ox_lib`,
`qb_menu`, `progressbar` or `qb_lock` only for an intentional provider override.

## Config

`Config.Bridge` keeps automatic detection for framework/inventory/target/database;
the resource-owned UI is explicit:

```lua
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
```

Explicit values are useful when multiple compatible resources are running.
Adapter contracts are validated before selection. Gameplay modules use only
`Bridge.GetPlayer`, `Bridge.GetJob`, `Bridge.GetPlayerData`,
`Bridge.HasPermission`, `Bridge.Notify`, inventory methods, target methods and
UI methods; vendor exports stay inside adapter files.

Security is enabled by default. `Config.Debug.enabled`,
`Config.Metrics.enabled` and `Config.RandomFailure.enabled` are disabled by
default. Use server ACE for admin mutations.

## Framework and inventory behavior

QBCore, Qbox and ESX adapters normalize player, job, permission and notify
behavior. Permission checks use ACE as final authority. Dedicated inventory
adapters are preferred; `framework` delegates item operations to the active
framework. `none` fails item checks closed, so item-required sabotage/repair
must be configured with an inventory or with `requireItem = false` for a
standalone server.

## Persistence

Transformer, incident and parent override state survives restart when
`oxmysql` is selected and the existing additive schema is imported. No new
SQL migration is added by the universal bridge work. Persistence calls only
`Bridge.Database`; oxmysql uses documented async exports.

Without SQL, `memory` adapter is selected. Grid, incident, repair and recovery
continue during the current process; state is intentionally lost after
restart. A missing database is logged as a warning, not a server crash. If
oxmysql starts after this resource, bridge re-detection performs one late
restore.

## Admin and diagnostics

```text
/blackoutbridge
/reloadtopology
/resyncvisual [playerId|all]
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
```

All mutation commands require configured admin permission, explicit target
type/id where applicable, and structured audit logging. `/reloadtopology`
revalidates loaded tables and rebuilds runtime indexes; it never loads Lua
files or changes SQL schema. `/resyncvisual` only refreshes client visual
state.

## External API and events

Existing server exports and power events remain unchanged. Current exports
include grid, feeder, substation, district, position, power-path, affected
district and active-incident queries. Unknown IDs return `nil, error`.

Optional dispatch, ATM, CCTV and doorlock integrations remain soft adapters;
missing resources cannot crash the power grid. Internal dispatch event:
`infra:dispatchIncident`.

## Topology extension

1. Add district registry data in `shared/districts.lua`.
2. Add grid/substation/transformer data in `shared/grids.lua` and feeder data
   in `shared/feeders.lua`.
3. Add a visual profile only when an asset/profile exists; do not invent map
   coordinates or duplicate citywide map assets.
4. Run validation before live use. Broken references refuse boot when strict
   topology validation is enabled.

## Tests

Run framework-free unit tests with Lua 5.4:

```text
lua5.4 tests/run.lua
```

Tests cover topology, power policy, recovery, random failure, security,
metrics, restart/resync, integration contracts and universal bridge contracts.
Live acceptance steps are kept outside this README and recorded briefly in
`CHANGELOG.md`.
