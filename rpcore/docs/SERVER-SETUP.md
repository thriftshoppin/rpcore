# Server setup: RPCore native HUD as a required client mod

Based on open2077.net/docs/server-mods, /docs/mods, /docs/rtti and /docs/tunables (Alpha docs; re-check
them, the platform is changing).

## 1. Resource and permissions
1. Put `rpcore/` in `resources/` and add it to `resources.load` in `server.jsonc`.
2. In Warden approve the permissions RPCore requests, including **`rtti.native`** (new).

## 2. Required mod (the redscript pack)
`rpcore/open77.lua` declares `preload_mod "dist/rpcore-hud.zip"`. On start the server stages it and logs
`Required mods: N declared, digest=...`. Requirements:
```jsonc
"requiredMods": { "enabled": true, "unsecured": true, "packages": [] }
```
- `enabled` must be true, or the server refuses to start (a selected resource declares a preload).
- The pack is **executable** (`.reds`). Either `unsecured: true` (players get an UNSECURED badge and a join
  confirmation; right for a trusted community), or get the exact hash verified: Warden -> Mods -> request
  review for the SHA-256 in `rpcore/dist/rpcore-hud.zip.sha256`. Every rebuild changes the hash; a review
  can be revoked; do not schedule a launch around a review date.
- Restart the server after changing the pack. Players must connect through the launcher (or accept the
  in-game "Restart required" prompt, which relaunches through it). A client that somehow lacks the pack
  gets one chat line and no bars; the base HUD is unaffected.

## 3. Configure (Warden -> Tuning)
Tier bounds, hysteresis, relic malfunction on/off and strength, override lifetimes, and the master switch
are live tunables (see `NATIVE-HUD.md`). Nothing needs a restart.

## 4. Rebuild the pack after editing redscript
`python3 tools/build-client-pack.py` (deterministic zip, game-root relative `r6/scripts/RPCore/*.reds`,
writes the `.sha256`). Then restart the server and relaunch clients through the launcher.

## 5. Verify
Server log: `Required mods: ... digest=...`. Launcher log: `world '<name>': projected N file(s)`.
Game: `r6/scripts/RPCore/` present, no redscript error dialog, `/rpcore.hud.native.ping`, then
`TEST-CHECKLIST.md`.

## Not covered
Package id/hash verification state for `rpcore-assets`, Warden's Mods page behaviour with a resource-owned
executable preload, and whether Open77's multiplayer policy strips relic effects on your build: all need
a live server.

## Switching to Solo (reverting the game files)

The pack only **adds** new files (`r6/scripts/RPCore/RPCoreHudSystem.reds`, `RPCoreHudBars.reds`); it replaces
nothing the game or Open77 ships, so removal is clean. Per the platform docs the launcher keeps the pack in a
per-world profile, separate from the player's own game:
- Pressing **Solo** in the launcher's mod menu projects the player's own mod set and takes the world layer out:
  both `.reds` files are removed from `r6/scripts/RPCore/`, so the game compiles without them. World files never
  appear in Solo.
- The mod menu's **Worlds** section lists these files under the world that required them, with a "remove this
  world's mods" action. Joining another world swaps world files; leaving the server never needs a manual uninstall.
- Cached bytes stay in the launcher's store until the player frees the space.
- Nothing from RPCore lingers in the game: the pack keeps no files outside `r6/scripts/RPCore/` and the vanilla
  health bar is never modified. If the game is somehow started with the pack but no RPCore feed, the bars stay
  hidden and no effect runs (nothing is pushed, nothing is applied at Stable).
Prove the round trip once on a test client (join, then Solo, then check the folder is gone) before relying on it.

## RP server load list (with Freeroam)

Verified against a real `server.jsonc` on 2026-10-11:

- Load `eventcore` before `rpcore`, and `rpcore` once.
- Load `open77_chat`. EventCore chat depends on it and the manifest does not enforce that.
- Freeroam is the only stock resource that respawns dead players (`open77_death` is read-only). Load `freeroam` with `install/disable-freeroam-hud.patch` applied (and optionally `install/disable-freeroam-killfeed.patch`). Freeroam's dependencies, including `open77_cyberware_lab`, must also be loaded. Do not add a second respawn resource alongside it.
- Only Freeroam and RPCore call `Open77.hud`. With the HUD patch applied, Freeroam no longer hides the game's health, stamina, weapon and speedometer widgets.
- `/rpcore.vanilla` and `/rpcore.hud.native` print to the client log and to chat. Other `[rpcore]` debug lines are client-log only.

## Not in this package

`tools/build-client-pack.py` and the `redscript/` source tree referenced by section 4 and `NATIVE-HUD.md` are not shipped here. Only the prebuilt `dist/rpcore-hud.zip` and its `.sha256` are included, so the pack cannot be rebuilt from this repository.

## Known issues

Vanilla health and "lifelihood" bars do not display properly, and wider screen aspect ratios display incorrectly. Both are operator-reported known issues from the 2026-10-11 in-game test, not setup errors.
