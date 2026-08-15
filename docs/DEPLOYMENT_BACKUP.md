# Deployment backup plan

Before a production update, store timestamped backups outside the live resource directory.

Back up:

- The current resource directory.
- The `infrastructure_transformers`, `infrastructure_incidents`, and `infrastructure_component_overrides` tables.
- `server.cfg`, permissions, and resource configuration.
- The current version tag and deployment notes.

Example database outline:

```bash
mysqldump --single-transaction --routines --triggers <database-name> > infrastructure-<timestamp>.sql
```

Example PowerShell outline:

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Copy-Item -Recurse -LiteralPath '<resource-path>' -Destination "<backup-root>\gnsh-blackout-$stamp"
```

Use the server's secret manager or protected environment for database credentials. Do not place credentials in this document or in the repository. Verify that both resource and database backups can be restored before deleting the previous release.
