# Rollback procedure

Use this procedure when a release causes state, persistence, security, replication, or visual failures.

1. Stop the affected resource and record the current tag, database state, and console error.
2. Restore the previous known-good resource archive or checkout.
3. Restore the matching configuration and permissions backup.
4. If the migration changed data, use the tested down migration or restore the pre-release database backup. Never guess on a destructive rollback.
5. Restart the resource and verify boot order, persistence restore, replication, and cleanup.
6. Run the staging smoke test before reopening production gameplay.
7. Record the incident and keep the broken release unavailable until fixed on `dev`.
