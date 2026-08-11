# Security Model

All client-originated mutation paths are server-authoritative.
`server/security_manager.lua` centralizes:

- source/ping/ped validation;
- bounded strings and component-type whitelists;
- topology-backed target existence;
- server-side distance checks;
- per-source event rate limits;
- ACE admin checks;
- one-owner, one-use interaction sessions;
- target revision checks to reject stale completions.

Sabotage and repair completion events validate the session, target, action,
revision and distance again. Repair stage values from a client are never
trusted as the next server stage. Duplicate success is idempotent and cannot
create a second mutation.

Admin operations require `Config.Debug.adminGroup` permission (server console
source `0` is allowed), accept explicit target type and ID, reject unknown
IDs, and write `ADMIN_ACTION` or `SECURITY_REJECTED` structured log events.

Clients cannot choose damage, incident impact, district list, grid state or
parent failure state. Security failures are rejected without partial state
mutation.
