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
