# Security Model

All client-originated mutation paths are server-authoritative.
`server/security_manager.lua` centralizes:

- source/ping/ped validation;
- bounded strings and component-type whitelists;
- topology-backed target existence;
- server-side distance checks;
- per-source event rate limits;
- QBCore/ACE admin checks, configured FXServer command ACE permissions
  (`command`, `command.refresh`, `command.restart` by default), plus the
  server-local txAdmin admin snapshot;
- one-owner, one-use interaction sessions;
- target revision checks to reject stale completions.

Sabotage and repair completion events validate the session, target, action,
revision and distance again. Repair stage values from a client are never
trusted as the next server stage. Duplicate success is idempotent and cannot
create a second mutation.

Admin operations require either the configured framework/ACE permission, one
of the configured command ACE permissions, or, when Config.Security.txAdmin is
enabled, a server-local txAdmin adminAuth/adminsUpdated authorization. Server
console source 0 is allowed. This keeps in-game resource admin commands
consistent with operators who are already allowed to run `refresh` or
`restart` through FXServer ACE.
Commands accept explicit target type and ID, reject unknown IDs, and write
ADMIN_ACTION or SECURITY_REJECTED structured log events.

The txAdmin events are registered with AddEventHandler only; they are not
network events and cannot be granted by a client. A player must be
authenticated in-game by txAdmin after the resource starts before the
snapshot can authorize that player; logging into the web panel alone is not
enough. The client may request txAdmin's own auth check automatically, but
the authorization decision still arrives only through txAdmin's server-local
event. Disconnects revoke the cached NetId.

The in-game /blackoutauth command only asks txAdmin to re-run that
server-side check; it does not grant or bypass admin permission.

Clients cannot choose damage, incident impact, district list, grid state or
parent failure state. Security failures are rejected without partial state
mutation.

## Bridge and UI boundary

External framework, inventory, UI and database calls are isolated in adapter
files. Adapter selection validates required functions and falls back before
gameplay starts. Native fallback UI never creates a browser frame or accepts
browser callback payloads.

UI adapters never supply damage, impact, district, grid state, repair stage, item
result or incident cause. Sabotage and repair completion still require a
server-owned interaction session, expected action/stage, target revision,
source ownership and current distance. Inventory checks and item consumption
run server-side. `memory` database mode only disables restart persistence; it
does not bypass authorization or session checks.
