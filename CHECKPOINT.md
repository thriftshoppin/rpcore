# RPCore HUD migration checkpoint — 0.2.0-beta.2

## Direction confirmed

RPCore is the updated home for the current SIM: Night City HUD. This iteration moves the HUD into RPCore and updates its framework connection; it does not replace the established HUD experience. The old `simnc_hud` resource must be unloaded after the migrated RPCore resource is installed, so players see one copy.

## Implemented in this stage (static review)

- Started from the existing RPCore 0.1.1 source in a separate working copy. The prior source and prior release archives were left unchanged.
- Updated the working resource to 0.2.0-beta.2 and declared EventCore 0.3.0-beta.2 as its dependency.
- Added EventCore service discovery/status, provider-call scaffolding, and ordered RPCore presentation delivery through EventCore's `EmitClient` export.
- Moved the HUD entry scripts under RPCore and routed its state through EventCore's versioned client feed. RPCore now publishes Open77 server identity, life state, and vitals; the direct `simnc_core` `SimncState` read has been removed.
- Preserved the existing RPCore activity offers, action flow, tracker, result/reward UI, journal, commands, and consumer exports.
- Added rebindable controls for settings, accept, decline, action, journal, and HUD visibility. Added an in-game HUD-styled controls panel with cheatsheet, key capture, reset-to-test-default, and Escape handling. Test defaults: F6, F7, F11, F12, Insert, Home.
- Updated the load-order fragment to require EventCore before RPCore and remove the separate `simnc_hud` surface. SIMNC domain data and spawn behavior remain to be migrated; the admin tools stay in their existing resource for the separate security review.
- Added migration plan and installation/limits documentation in the resource README.

## Needs in-game verification

- Resource manifests and Warden permissions are accepted by the target Open77 build.
- EventCore is installed before RPCore, its documented export call works, and activity UI packets reach the player.
- HUD display parity, EventCore state delivery, surface ordering, settings focus behavior, and key persistence still need in-game verification.
- Confirm the bundled `open77_admin` panel and commands remain available with their original ACLs; they are not included or modified by this HUD-only resource package.
- Confirm no visible duplicate surface remains after removing `simnc_hud` from the load list.

## Not implemented in this stage

SIMNC-specific money, job, needs, humanity, weather, character login, and spawn behavior are not represented as complete. This feed slice publishes only platform identity/life/vitals. The admin panel and its ACL controls are not migrated.

## Artifacts

- Working source: this repository's `rpcore/` resource.
- Migration plan: `work/rpcore_eventcore/RPCORE_HUD_MIGRATION_PLAN.md`
- Load-order merge example: `rpcore/install/server-load-order.jsonc`
- Package: release archive not built yet.
