# RPCore contributor handoff

## Current local work

- RPCore 0.3.2 makes `/rpcore.map` and the rebindable M action open the native City Map, selecting RPCore's Locations tab when available. Controller B opens the map while it is closed; the native map owns its B/back behavior after it opens.
- The previous bug was that adding a native map tab did not itself open the native map. `rpcore/client/map.lua` now owns the open request, handles Open77's map lifecycle events, and only closes a native session RPCore opened.
- Use Cyberpunk's native minimap and City Map. RPCore creates native game blips and a Locations tab; it must not draw or imitate map tiles. Open77 currently does not expose a supported API to relocate the minimap into a custom lower-left HUD panel.
- RPCore releases only its own native minimap hide claim at startup. `/rpcore.map.minimap` reports whether the minimap remains hidden by another resource.
- The player's minimap switch is in Open77 player settings: Pause (`Escape`) → Settings → Gameplay → HUD Elements → Minimap (`/interface/hud`, `minimap`). `/rpcore.map.minimap on` sets that player option and reports the HUD-claim state plus perspective; it is not a server-wide/game-wide map setting. Open77's third-person mode hides the native HUD, including the minimap; check the reported perspective if the map still drops after spawn.
- The native minimap has a game-owned fixed screen position. The documented Open77 APIs expose visibility and native blips, not relocation or extraction into an RPCore bottom-left WebUI. Do not draw a fake map; a true relocated minimap needs a separate implementation using actual game map data or a supported host API.
- Open77 Perspective and RPCore Controls both default to F6 in this server setup. This is a key collision worth resolving before treating F6 as a diagnostic result.
- See `CHANGELOG.md`, `rpcore/README.md`, and `CHECKPOINT.md` for the user-facing behavior and remaining in-game checks.

## Handoff and release

- Repository: `thriftshoppin/rpcore`; installable resource is in `rpcore/`.
- Test server resource lives under `C:\Users\Open77\Downloads\open77-server-2.31.21+op77.131-win-x64\resources\rpcore`.
- The minimap-setting and chat diagnostic updates have been published; the player confirmed the native minimap appears and its default is controlled by their player settings. In-game verification is still needed for `/rpcore.map`, M, `/rpcore.map.minimap on`, controller B, native map tab selection, saved locations, and map permissions.
- Do not commit, push, or deploy until the user explicitly says “okay” for the pending changes. The user wants testing before GitHub publication and deploys only after local commits.
- Do not add a license before publication. The user reserves the right to choose release licensing later.
