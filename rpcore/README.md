# RPCore 0.2.0-beta.2 — HUD state feed integration

RPCore is the updated home for the SIM: Night City HUD and the server-agnostic RP activity HUD. This is a continuation of the existing HUD: the SIMNC character display, vitals, weapon card, crosshair, and blood overlay move into RPCore with their established display behavior. RPCore also retains its activity offers, tracker, journal, developer commands, and consumer exports.

## Install and load order

1. Copy this `rpcore/` folder into the server's `resources/` folder.
2. Install EventCore 0.3.0-beta.2 or newer into the same resources root.
3. In `server.jsonc`, put `eventcore` before `rpcore`. Remove `simnc_hud` from the load list after RPCore is installed, so the old and moved HUD surfaces do not both render. RPCore no longer reads `simnc_core` state.
4. Restart the server. Confirm both resources start without errors; `/rpcore.status` reports the EventCore connection.
5. In game, use `/rpcore.demo` to see the activity HUD. Press **F6** for RPCore Controls. Accept **F7**, decline **F11**, action **F12**, journal **Insert**, and HUD visibility **Home** are test defaults. Change or reset each binding in the panel or the game's key-binding settings.

The supplied overlay at `install/server-load-order.jsonc` illustrates the two load-list edits. Merge them into the server's existing resource list; do not replace the server configuration with the overlay.

## Preserved HUD surfaces

- Migrated HUD surface/layout and visual elements; this beta's EventCore feed populates platform identity, life state, and vitals only.
- Weapon/ammunition card, third-person crosshair, and blade-hit blood overlay.
- Existing activity offer, accept/decline flow, objectives, results/rewards, journal, resource commands, and public consumer exports.
- F6 settings panel with the keybinding cheatsheet, per-action rebind, reset-to-test-default, and Escape close behavior.
- Existing admin panel remains inside the still-loaded `simnc_core` resource with its existing access controls; this player HUD does not replace or absorb its privileged tools.

## EventCore integration

RPCore requires EventCore and discovers its runtime/service catalog through documented exports. Activity presentation is delivered through EventCore's `EmitClient` route. HUD snapshots are built from Open77 server identity, life state, and vitals, then published through EventCore's versioned state feed. SIMNC-only money, job, needs, humanity, weather, and character-session behavior are still migration work; they are not read from SIMNC as a fallback.

## Important limits

- This package has not been verified in a running Open77 game/server. HUD state delivery, Warden permissions, resource activation, key rebinding, and z-order need in-game verification.
- Only the platform-backed name, life state, and vitals are currently published. The remaining SIMNC-specific fields need replacement providers before all HUD values can match the former system.
- RPCore activity history remains in memory in this beta. EventCore persistence and durable player inventory/outfits are future integration stages, not part of this package.
- Defaults are selected for low collision against the supplied SIMNC resource bindings and are fully changeable. F12 is also commonly used by platform software; rebind it if it conflicts on your setup.

## Contents

- `server/`: server-authoritative activity engine, EventCore adapter, and HUD snapshot publisher.
- `client/`: activity HUD, input menu, and RPCore HUD renderers.
- `web/`: RPCore activity HUD plus the migrated SIMNC UI, images, fonts, weapon, crosshair, and blood layers.
- `install/server-load-order.jsonc`: small load-order merge example.
- `docs/CONSUMING.md`: RPCore activity API for other resources.
