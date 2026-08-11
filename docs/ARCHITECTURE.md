# Architecture

`gnsh-blackout` has two deliberately separated domains:

- Logical Power Domain: server-owned grid, substation, feeder, transformer,
  incident and district state.
- Visual Power Domain: client district detection, profile resolution and
  native/hybrid visual adapters.

The topology is `GRID -> SUBSTATION -> FEEDER -> TRANSFORMER -> DISTRICT`.
`GridManager` builds runtime indexes from `shared/grids.lua` and
`shared/feeders.lua`. `PowerCalculator` derives aggregate states;
`Replication` publishes immutable snapshots with revisions to `GlobalState`.
Clients never decide damage, impact, district power, grid power or incident
state.

## Boot order

Validation runs before runtime initialization. Persistence is loaded first,
then topology/runtime indexes, transformer and parent overrides, incidents,
grid calculation, district replication and finally the random-failure
scheduler. Client startup reads the current district snapshot and applies
visual state instantly, so restart does not replay a failure transition.

## Failure and recovery

Transformer mutations use `TransformerManager`; parent overrides use
`FailureManager`; both recalculate through `Replication`. Incidents use
`IncidentManager` and optional `DispatchBridge`. A parent being offline blocks
its descendants without changing their underlying child state. Restoration
therefore exposes the child's real state and preserves partial recovery.

## Visual resolution

`VisualProfiles.Resolve(districtId, gridId)` applies district profile, grid
profile, then `native_default`. `NATIVE_CLIENT_GATE` is always the fallback.
`HYBRID` is an optional adapter hook and cannot mutate logical power state.

## Extension seams

Framework, inventory, target, dispatch and visual adapters are soft unless
explicitly declared in `fxmanifest.lua`. Persistence is provided by the
existing `oxmysql` tables; no Phase 26-35 migration is introduced.
