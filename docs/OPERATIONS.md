# Operations

## Production defaults

- `Config.Debug.enabled = false`
- `Config.RandomFailure.enabled = false`
- `Config.Metrics.enabled = false`
- `Config.Security.enabled = true`
- `Config.Topology.strict = true` is recommended for production after the
  registry has been audited.

Import the existing `sql/schema.sql` before relying on restart persistence.
Do not drop or replace existing tables. `oxmysql` must start before this
resource.

## Admin gateway

All state-changing commands use explicit IDs:

`/setgridstate`, `/setsubstationstate`, `/setfeederstate`, `/restoregrid`,
`/restoresubstation`, `/restorefeeder`, `/restoretransformer`,
`/createincident`, `/resolveincident`, `/reloadtopology`, and
`/resyncvisual [playerId|all]`.

`/reloadtopology` validates loaded registries and rebuilds runtime indexes; it
does not load Lua files or alter SQL. `/resyncvisual` only asks clients to
re-read their replicated district state.

## Recovery and restart

Restore parent infrastructure before diagnosing a child. An offline child
remains offline after parent restoration; an online child recovers when all
required parents are online. A resource restart restores persistence before
publishing grid/district state. A reconnect and late join receive the current
snapshot and do not replay an old blackout transition.

## Production checklist

- Validate topology and import the existing SQL schema.
- Configure ACE for the admin group.
- Keep debug tools disabled unless diagnosing a controlled issue.
- Confirm optional bridge resources have safe fallbacks.
- Monitor `SECURITY_REJECTED`, `SECURITY_RATE_LIMITED`, persistence errors
  and incident lifecycle logs.
- Enable bounded metrics only for a measurement window.
- Perform live acceptance before changing the release candidate to `1.0.0`.

## Bridge operations

- Keep framework/inventory/target/database bridge values on `auto`; keep
  `notify`, `menu`, `progress` and `skillcheck` on `nui` for the universal UI.
- Run `/blackoutbridge` after `refresh`/`restart gnsh-blackout` and after
  starting or stopping a framework, inventory, target or database resource.
- `database=memory` means current-session operation only; it is not a SQL
  replacement.
- Verify sabotage/repair `requireItem` settings match selected inventory.
  `none` intentionally fails item checks closed.
- A target resource restart should produce one bridge rebuild and no duplicate
  interactables. Provider errors must fall back to standalone/internal mode.
