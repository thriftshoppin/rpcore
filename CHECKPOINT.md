# RPCore HUD migration checkpoint — 0.2.0-beta.1

## Direction confirmed

RPCore is the updated home for the current SIM: Night City HUD. This iteration moves the HUD into RPCore and updates its framework connection; it does not replace the established HUD experience. The old `simnc_hud` resource must be unloaded after the migrated RPCore resource is installed, so players see one copy.

## Implemented in this stage (static review)

- Started from the existing RPCore 0.1.1 source in a separate working copy. The prior source and prior release archives were left unchanged.
- Updated the working resource to 0.2.0-beta.1 and declared EventCore 0.3.0-beta.1 as its dependency.
- Added EventCore service discovery/status, provider-call scaffolding, and ordered RPCore presentation delivery through EventCore's `EmitClient` export.
- Moved the SIMNC HUD scripts and web assets under RPCore: player information/vitals, weapon display, crosshair, and blood overlay. Retained the `simnc_core` `SimncState` read as a compatibility adapter.
- Preserved the existing RPCore activity offers, action flow, tracker, result/reward UI, journal, commands, and consumer exports.
- Added rebindable controls for settings, accept, decline, action, journal, and HUD visibility. Added an in-game HUD-styled controls panel with cheatsheet, key capture, reset-to-test-default, and Escape handling. Test defaults: F6, F7, F11, F12, Insert, Home.
- Added an install load-order fragment: EventCore before RPCore; keep `simnc_core` before RPCore; remove `simnc_hud` after migration. `simnc_core` (which contains the supplied admin panel) and `simnc_blood` remain loaded and unchanged.
- Added migration plan and installation/limits documentation in the resource README.

## Needs in-game verification

- Resource manifests and Warden permissions are accepted by the target Open77 build.
- EventCore is installed before RPCore, its documented export call works, and activity UI packets reach the player.
- Existing HUD display parity, surface ordering, optional SIMNC state adapter, settings focus behavior, and key persistence work in game.
- Confirm the admin panel inside `simnc_core` remains available with its original ACLs; it is not included or modified by this HUD-only resource package.
- Confirm no visible duplicate surface remains after removing `simnc_hud` from the load list.

## Not implemented in this stage

EventCore domain providers for inventory, outfits, character data, and durable mission/player state are not represented as complete. The current beta does not claim SQL persistence or server-managed clothing. The SIMNC client state reader remains until owner-backed server provider contracts can replace it without changing what the HUD displays.

## Artifacts

- Working source: `work/rpcore_eventcore/resources/rpcore/`
- Migration plan: `work/rpcore_eventcore/RPCORE_HUD_MIGRATION_PLAN.md`
- Load-order merge example: `rpcore/install/server-load-order.jsonc`
- Package: `RPCore_0.2.0-beta.1_HUD_MIGRATION.zip`
