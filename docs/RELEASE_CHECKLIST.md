# Production release checklist

## Before merge

- [ ] Work is merged from `dev` after review.
- [ ] CI is green for the exact commit being released.
- [ ] `fxmanifest.lua` version and `CHANGELOG.md` agree.
- [ ] No secrets, local server files, or generated output are included.
- [ ] Security, restart/resync, persistence, and live acceptance checks passed.

## Release

- [ ] Create an annotated tag such as `v0.35.0-rc.1` or the accepted stable version.
- [ ] Create a GitHub Release from that tag.
- [ ] Archive the exact resource directory used for deployment.
- [ ] Back up the database, `server.cfg`, permissions, and resource configuration.
- [ ] Apply and verify the required SQL before resource restart.
- [ ] Deploy the tagged resource to staging first.
- [ ] Run the staging matrix in `STAGING_TEST_MATRIX.md`.

## Production

- [ ] Confirm the maintenance window.
- [ ] Stop or restart only the affected resource.
- [ ] Check the server console for startup and database errors.
- [ ] Run the smoke test and confirm grid, incident, sabotage, repair, replication, and restart flows.
- [ ] Keep the previous tag and database backup available until acceptance is complete.
