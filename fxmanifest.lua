fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'gnsh'
description 'City Infrastructure — Dynamic Power Grid, District Blackout, Fault, Sabotage, Repair & Incident Framework (Phase 1-35)'
version '0.35.0-rc.1'

-- qb-core / qb-target are still soft-detected at runtime by
-- bridge/loader.lua and degrade gracefully if absent (RULE 8 — core must
-- not hard-depend on the FRAMEWORK). ox_lib and menuv need the
-- '@ox_lib/init.lua' / '@menuv/menuv.lua' imports below (so the `lib` /
-- `MenuV` globals exist in THIS resource's isolated Lua state — confirmed
-- via menuv/README.md, cross-resource globals aren't a thing).
--
-- ox_lib, menuv, ox_inventory and oxmysql are hard dependencies because
-- this resource imports their Lua entry points directly or uses their
-- persistence wrapper. Explicit declarations make a missing dependency
-- fail at resource startup instead of producing a partial runtime.
-- Reason: bridge/loader.lua's resolveInventoryKey() auto-detects via
-- GetResourceState() ONCE at gnsh-blackout's own startup — a snapshot,
-- not a live check. server.cfg's `ensure [standalone]` starts that whole
-- folder in (effectively) alphabetical order, and 'gnsh-blackout' sorts
-- BEFORE 'ox_inventory', so gnsh-blackout was locking onto the 'none'
-- inventory adapter (a no-op stub) every boot — Bridge.HasItem always
-- returned false regardless of what was in the player's actual inventory
-- (live testing, 2026-08-08: player had 39x thermite, server still said
-- "gerekli eşyanız yok"). A hard dependency forces correct start order.
--
-- IMPORTANT — menuv/menuv.lua declares its OWN bare global `Config` (its
-- own settings table) and, since it's imported straight into this
-- resource's client_scripts, it silently overwrites gnsh-blackout's own
-- `Config` the instant it loads (found via live testing, 2026-08-08:
-- bridge/loader.lua reading `Config.Bridge` as nil immediately after
-- config.lua had just populated it — client-only, since menuv is only
-- imported client-side). config.lua stashes a collision-proof backup at
-- `_G.__GnshBlackoutConfig`, and 'client/restore_config.lua' restores it —
-- that file MUST stay directly after the menuv import and before
-- bridge/loader.lua (or anything else that reads Config) in the
-- client_scripts list below.
--
-- oxmysql (Phase 14 persistence): '@oxmysql/lib/MySQL.lua' import gives
-- server/persistence.lua the `MySQL` global (oxmysql's own official Lua
-- wrapper). A hand-rolled raw `exports.oxmysql[...]` call was tried
-- first to keep this soft — it silently failed on every WRITE (found via
-- live testing, 2026-08-08: sabotaged transformer state never reached
-- the DB, so a restart brought power back instead of preserving the
-- blackout) — see server/persistence.lua's header note for the full
-- story. This is now a real hard dependency, same as ox_lib/menuv/
-- ox_inventory.
dependency 'ox_inventory'
dependency 'oxmysql'
dependency 'ox_lib'
dependency 'menuv'

shared_scripts {
    'config.lua',

    'shared/utilities.lua', -- must load before shared/constants.lua (Utils.FreezeShape is called at constants.lua's load time)
    'shared/constants.lua',
    'shared/types.lua',
    'shared/districts.lua',
    'shared/grids.lua',
    'shared/feeders.lua', -- Phase 18 — references Substations/Transformers ids as strings, loaded after grids.lua for logical ordering
    'shared/world_placement.lua', -- Phase 22 — physical placement registry, built after topology
    'shared/zone_resolver.lua',

    'profiles/sandy.lua', -- must load before shared/validators.lua
    'profiles/ls_central.lua', -- Phase 18, same ordering requirement
    'shared/visual_profile_resolver.lua', -- Phase 28 district -> grid -> native fallback

    'shared/validators.lua',

    'bridge/framework/standalone.lua',
    'bridge/framework/qbcore.lua',
    'bridge/inventory/ox_inventory.lua',
    'bridge/inventory/qb.lua',
    'bridge/inventory/none.lua',
    'bridge/target/menu_helper.lua', -- must load before qb_target/textui/standalone: they call MenuHelper.OpenOptions()
    'bridge/target/qb_target.lua',
    'bridge/target/textui.lua',
    'bridge/target/standalone.lua',
    'bridge/target/none.lua',
}

client_scripts {
    '@ox_lib/init.lua', -- must load first: client/sabotage.lua's minigame uses the `lib` global
    '@menuv/menuv.lua', -- must load before any interaction: bridge/target/menu_helper.lua's MenuV:CreateMenu() needs the `MenuV` global

    'client/restore_config.lua', -- MUST come right after the menuv import: undoes menuv.lua's own global `Config` clobbering ours (see header comment above)

    'bridge/loader.lua', -- assembles `Bridge` from the adapters above (client side)

    'client/state.lua',
    'client/metrics.lua', -- Phase 27 bounded client measurements
    'client/zone_resolver.lua',
    'client/district_manager.lua',

    'client/visual/ownership.lua',
    'client/visual/native_blackout.lua',
    'client/visual/transition.lua', -- must load before manager.lua: it calls Transition.PlayBlackout/PlayRecovery/ForceSync/Cancel
    'client/visual/hybrid.lua', -- Phase 28 optional visual adapter; never owns logical power state
    'client/visual/manager.lua',

    'client/sabotage.lua',
    'client/repair.lua',
    'client/debug.lua',
    'client/main.lua', -- orchestrator, loads last
}

server_scripts {
    '@oxmysql/lib/MySQL.lua', -- must load before server/persistence.lua: gives it the `MySQL` global
    'server/logging.lua', -- must load before bridge/loader.lua (server side calls Log.event on boot)
    'server/metrics.lua', -- Phase 27 bounded server measurements
    'server/persistence.lua',
    'bridge/loader.lua',  -- assembles `Bridge` from the adapters above (server side)
    'server/security_manager.lua', -- Phase 26 server boundary validation

    'server/zone_resolver.lua',
    'server/grid_manager.lua',
    'server/failure_manager.lua', -- Phase 21 parent failure overrides
    'server/substation_manager.lua',
    'server/feeder_manager.lua', -- Phase 18, same "thin/derived, no Init()" pattern as substation_manager.lua
    'server/transformer_manager.lua',
    'server/incident_impact.lua', -- Phase 23 topology impact calculation
    'server/dispatch.lua', -- Phase 23 optional dispatch bridge; no hard dependency
    'server/incident_manager.lua',
    'server/interaction_manager.lua',
    'server/sabotage.lua',
    'server/repair_manager.lua',
    'server/power_calculator.lua',
    'server/api_helpers.lua', -- Phase 24: pure deep-copy/input validation contract
    'server/replication.lua',
    'server/api.lua',
    'server/random_failure_manager.lua', -- Phase 25 server-only automatic failures
    'server/debug.lua',
    'server/admin_operations.lua', -- Phase 30 explicit, ACE-gated operations

    'server/main.lua', -- orchestrator, loads last: validates config, boots the runtime cache
}
