# RPCore 0.4.0 — Open77 server resource

> Development/playtest build. Project playtesting is incomplete; this resource is not ready for general release.

<u>**You must own a valid copy of Cyberpunk 2077 and Phantom Liberty to download and use these modifications.**</u> Follow the current game, REDmod, and platform terms. See the required HUD mod's [project use terms](../rpcore-hud/README.md#project-use-terms).

This directory is the Open77 server resource. It owns RPCore's server-side activity/HUD services, validates trusted provider calls, and relays client-safe state through EventCore. The related client mod is documented at the repository root in [`rpcore-hud/`](../rpcore-hud/README.md); the two components are designed to work together.

## Required client HUD mod

The bundled `dist/rpcore-hud.zip` is the required redscript patch announced to the OPEN//77 launcher. Its job is to carry EventCore-fed RPCore HUD data from the RPCore client bridge into the game's native HUD/`inkWidget` path. The HUD bars use that native client presentation path instead of a WebView. The patch does not decide when roleplay events happen; those triggers belong to EventCore/providers.

The source for this patch is in the repository-root [`rpcore-hud/`](../rpcore-hud/) directory. The `dist/` copy and its `.sha256` file are the server-delivered package and Warden review source of truth.

## Install

1. Copy this `rpcore/` directory into the Open77 server's `resources/` folder. Do not nest it inside `eventcore/` and do not load it more than once.
2. Install EventCore **0.6.1 or newer** and `open77_chat` in the same resources directory. Add `rpcore` to EventCore's `server/whitelist.lua`.
3. In `server.jsonc`, load `eventcore`, `open77_chat`, then `rpcore`. Enable `requiredMods`; the manifest preloads `dist/rpcore-hud.zip` for launcher delivery.
4. In Warden, review/approve the exact digest in `dist/rpcore-hud.zip.sha256` and approve RPCore's requested permissions, including `rtti.native`. Re-review any rebuilt package because its digest changes. `requiredMods.unsecured: true` is an alternative only when the operator intentionally accepts unsecured required mods.
5. On Freeroam servers, apply [`install/disable-freeroam-hud.patch`](install/disable-freeroam-hud.patch) from the server root to avoid duplicate HUD behavior. The optional [`install/disable-freeroam-killfeed.patch`](install/disable-freeroam-killfeed.patch) disables Freeroam's kill feed. Keep Freeroam or another respawn resource if the server needs respawning.
6. Restart. Check `/rpcore.status`; on a launcher-connected client, check `/rpcore.hud.native` and `/rpcore.hud.native.ping`.

Merge [`install/server.jsonc.snippet`](install/server.jsonc.snippet) into the existing server configuration. Do not replace the full configuration with the snippet. See [`docs/SERVER-SETUP.md`](docs/SERVER-SETUP.md) and [`docs/NATIVE-HUD.md`](docs/NATIVE-HUD.md) for operator details.

## Included behavior

- EventCore-fed hunger, thirst, and cyberpsychosis data for native HUD widgets.
- Provider exports for vitals, psychosis/tier overrides, bar visibility, and supported HUD element controls.
- Warden live tunables for native HUD settings, psychosis tiers/hysteresis, relic-effect settings, and override lifetimes.
- RPCore activities, objectives/results, journal, custom panels, weapon card, crosshair, blood overlay, native map locations and pins.

## Development limits

RPCore provides state handling and HUD presentation/control, but does not orchestrate mission or RP outcomes. The current EventCore build does not yet provide all planned triggers for damage red-screening, Blackwall/netrunning effects, or failed/imperfect task outcomes. The relic-effect label is under revision; the current build targets a vanilla Johnny-sickness effect that multiplayer policy may suppress. The scripted bars cannot create a Blackwall ink effect at runtime, so that effect may be absent.

The current operator-reported issues are vanilla health/lifelihood bars not displaying correctly and wide-aspect-ratio layout. Project playtesting is incomplete. See this folder's [`CHECKPOINT.md`](CHECKPOINT.md) and the required mod's [`CHECKPOINT.md`](../rpcore-hud/CHECKPOINT.md).
