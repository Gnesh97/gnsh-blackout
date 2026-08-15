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

## Citywide topology

All 90 native district codes are assigned exactly once across 11 logical
grids. The original city grids (`ls_central`, `ls_south`, `ls_west`,
`ls_vinewood`, `ls_east_industrial`) are supplemented by `ls_north` and
`ls_south_extension`; `blaine_north`, `blaine_central` and
`restricted_infrastructure` extend the existing `blaine_south` branch. Each
grid owns one substation, two independent primary feeders and two
transformers. The synthetic `HARMOSUB` overlap-test zone is assigned to
`blaine_central` but is not counted among the 90 native codes.

The 51 districts exposed through the `city` operational region follow the
mapped Los Santos boundary, including Tataviam Mountains (`TATAMO`). This
operational grouping may cross logical grid boundaries; the remaining native
districts are covered by the Blaine, wilderness and restricted logical grids
without inventing new district IDs.

Logical topology and physical placement stay separate. Existing verified
Sandy/Central points remain interactable. New substations and transformers
use `physical = false` until verified coordinates are supplied; they
participate in API, admin, incident, persistence and replication paths, but
do not expose a fake client interaction or spawned prop.

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

## Universal bridge

`bridge/core.lua` owns canonical aliases and adapter contracts. `bridge/loader.lua`
builds a new server/client snapshot, validates required functions, publishes it
atomically and records fallback reasons. Vendor calls live only in adapter
files. Framework, inventory, target, notify, menu, progress, skillcheck and
database categories can be selected independently.

Client target specs are retained by id. When a target resource starts or stops,
the old adapter removes every registered spec before the new adapter registers
them. This prevents duplicate zones during live resource changes. Native UI fallback
is the terminal UI fallback; it has no authority over logical power state.
