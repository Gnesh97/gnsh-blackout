# Integration Guide

## Topology

Use existing logical IDs only. Add district registry entries in
`shared/districts.lua`, grid/substation entries in `shared/grids.lua`, feeder
links in `shared/feeders.lua`, and physical points in
`shared/world_placement.lua`. Run the built-in validator before deployment;
do not create placeholder districts or coordinates to satisfy a reference.

## Server exports

The public surface is exposed through `exports['gnsh-blackout']`:

- `IsGridPowered`, `IsDistrictPowered`, `IsPositionPowered`
- `GetGridState`, `GetDistrictState`, `GetTransformerState`
- `IsSubstationPowered`, `IsFeederPowered`, `GetSubstationState`,
  `GetFeederState`
- `GetInfrastructureAtPosition`, `GetPowerPathForDistrict`,
  `GetAffectedDistricts`
- `GetActiveIncident`, `GetIncident`, `GetActiveIncidents`

Unknown IDs return `nil, error`. Returned tables are detached copies.

## Stable events

Consumers may subscribe to `gnsh-blackout:powerLost`,
`gnsh-blackout:powerRestored`, `gnsh-blackout:powerLevelChanged`, and the
internal `infra:dispatchIncident` event. Incident payloads contain target,
cause, severity, affected districts and estimated impact. Treat
`Constants.EVENT_VERSION` as the payload version contract.

ATM, CCTV, doorlock and dispatch integrations should consume these exports or
events through optional adapters. They must not become hard dependencies of
this resource.

## Framework bridges

`Config.Bridge` supports auto-detection or explicit framework, inventory and
target adapters. A missing soft dependency must resolve to a safe fallback;
bridge code must not be called directly by integration consumers.

## Universal adapter selection

Use `Config.Bridge.*` for explicit selection when automatic priority is not
desired. Supported framework values are `qbox`, `qbcore`, `esx` and
`standalone`; inventory values are `ox_inventory`, `qs_inventory`,
`ps_inventory`, `qb_inventory`, `framework` and `none`; target values are
`ox_target`, `qb_target`, `qtarget`, `standalone`, `textui` and `none`.
Notify/menu/progress/skillcheck/database categories expose resource-owned
`nui` first, then `internal`, `ox_lib`, `qb_menu`, `menuv`, `progressbar`,
`qb_lock`, `oxmysql` and `memory` where applicable. With `auto`, the client UI
categories therefore stay identical across QBCore, Qbox, ESX and standalone.
Legacy aliases are normalized.

Run `/blackoutbridge` after boot or after a provider restart. Output shows
active adapters, capabilities and fallback reasons. Consumers must use public
exports/events and must not call vendor APIs through this resource.

## Stack examples

```lua
-- QBCore + ox inventory/target + SQL
Config.Bridge.framework = 'qbcore'
Config.Bridge.inventory = 'ox_inventory'
Config.Bridge.target = 'ox_target'
Config.Bridge.database = 'oxmysql'

-- Standalone, no third-party UI or SQL
Config.Bridge.framework = 'standalone'
Config.Bridge.inventory = 'none'
Config.Bridge.target = 'standalone'
Config.Bridge.menu = 'nui'
Config.Bridge.progress = 'nui'
Config.Bridge.skillcheck = 'nui'
Config.Bridge.database = 'memory'
Config.Sabotage.requireItem = false
Config.Repair.requireItem = false
```

The standalone example still uses server-owned sessions, distance, revision
and rate-limit checks. Memory persistence is volatile by design.
