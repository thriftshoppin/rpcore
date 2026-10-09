# RPCore migration checkpoint — 0.2.3

## Current delivery status

- HUD visuals and the per-player layout editor are implemented in the local RPCore checkout. JavaScript syntax checks and `git diff --check` pass.
- The current changes are uncommitted and have not been copied to the server. Live drag/focus behavior still needs the requested test-bench playtest after the local commit is authorized and completed.
- Next sequence: get the user's explicit okay to commit, deploy those local commits to the test server, playtest the HUD/layout editor, then update GitHub only if the playtest passes.

## Direction confirmed

RPCore is the updated home for the current SIM: Night City HUD. This iteration moves the HUD into RPCore and updates its framework connection; it does not replace the established HUD experience. The old `simnc_hud` resource must be unloaded after the migrated RPCore resource is installed, so players see one copy.

## Implemented in this stage (static review)

- Started from the existing RPCore 0.1.1 source in a separate working copy. The prior source and prior release archives were left unchanged.
- Updated the working resource to 0.2.3 and declared EventCore 0.4.0 as its dependency.
- Added EventCore service discovery/status, provider-call scaffolding, and ordered RPCore presentation delivery through EventCore's `EmitClient` export.
- Moved the HUD entry scripts under RPCore and routed its state through EventCore's versioned client feed. RPCore now publishes Open77 server identity, life state, and vitals; the direct `simnc_core` `SimncState` read has been removed.
- Preserved the existing RPCore activity offers, action flow, tracker, result/reward UI, journal, commands, and consumer exports.
- Added rebindable controls for settings, accept, decline, action, journal, and HUD visibility. Added an in-game HUD-styled controls panel with cheatsheet, key capture, reset-to-test-default, and Escape handling. Test defaults: F6, F7, F11, F12, Insert, Home.
- Updated the load-order fragment to require EventCore before RPCore and remove the separate `simnc_hud` surface. SIMNC domain data and spawn behavior remain to be migrated.
- Added migration plan and installation/limits documentation in the resource README.
- RPCore restricted commands now call EventCore's trusted `IsAdmin` API after Open77 command permission grants.
- Replaced the circular vitals gauges with individual glass bars, color-corrected stamina to green and water to blue, and kept unavailable level/breath/food/water rows hidden until providers supply values.
- Added a per-player drag editor for the vitals, occupation, activity stack, journal, controls and weapon readout; `/rpcore.layout` and the rebindable F9 action open the editor.
- Added an install patch that disables the bundled Freeroam vitals page without disabling Freeroam gameplay or its scoreboard.

## Needs in-game verification

- Resource manifests and Warden permissions are accepted by the target Open77 build.
- EventCore is installed before RPCore, its documented export call works, and activity UI packets reach the player.
- HUD display parity, EventCore state delivery, surface ordering, settings focus behavior, and key persistence still need in-game verification.
- Confirm EventCore's admin panel opens and quick actions still pass through Open77's restricted command dispatcher.
- Confirm no visible duplicate surface remains after removing `simnc_hud` from the load list.

## Not implemented in this stage

SIMNC-specific money, job, needs, humanity, weather, character login, and spawn behavior are not represented as complete. This feed slice publishes only platform identity/life/vitals. EventCore owns the admin entry point, but most admin action handlers still live in Open77's existing tool resource and have not yet been ported.

## Artifacts

- Working source: this repository's `rpcore/` resource.
- Migration plan: `work/rpcore_eventcore/RPCORE_HUD_MIGRATION_PLAN.md`
- Load-order merge example: `rpcore/install/server-load-order.jsonc`
- Package: release archive not built yet.
