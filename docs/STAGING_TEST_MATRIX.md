# Staging test matrix

Record the version, date, tester, result, and notes for each row.

| Scenario | Expected result |
|---|---|
| Clean resource start | Validators pass; dependencies load; no unexpected console error. |
| Invalid topology/config fixture | Startup fails closed with an actionable error. |
| Grid/substation/feeder state change | Only the intended branch changes and replication revision advances correctly. |
| Sabotage request and failure | Server validates target, distance, item, session, cooldown, and final state. |
| Multi-stage repair | Stage, revision, distance, materials, and ownership checks remain server-authoritative. |
| Invalid/replayed event | Request is rejected without duplicate mutation or reward. |
| Player disconnect | Sessions, locks, repair bookkeeping, and temporary state are cleaned up. |
| Resource restart | Persistence restores state before replication and visual cleanup completes. |
| Two-player concurrent actions | Target locks and state transitions remain consistent. |
| Server restart and reconnect | Active persistent state, late join, and resync behave correctly. |
| Rollback smoke test | Previous tagged release and matching database backup restore cleanly. |
