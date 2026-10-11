# Changelog

## Unreleased
- Docs: recorded the licensing plan in `AGENTS.md` (all rights reserved while in development; MIT from the full release onward). No license file was added.
- Docs: the Freeroam HUD and kill-feed changes are also distributed as a complete patched `freeroam/` resource folder, packaged beside this repository (not inside it).
- Changed: `webFallback.vitals` now defaults to `false`, matching the file's own "ALL OFF" comment. The web vitals panel no longer draws by default and the base game HUD plus the native redscript bars are used.
- Docs: corrected the README claim that RPCore hides the native health, stamina and weapon widgets. By default it hides none (all `default` values are `nil`).
- Docs: install guidance now covers loading `open77_chat`, loading `rpcore` once, and the fact that Freeroam is the only stock resource that respawns players.
- Added `install/disable-freeroam-killfeed.patch` and regenerated `install/disable-freeroam-hud.patch` against the current Freeroam 0.7.4 sources (the old patch's line numbers did not match). Moved `INSTALL.txt` and `server.jsonc.snippet` into `install/`.
- Docs: recorded the operator-reported known issues from the 2026-10-11 in-game test (vanilla health and "lifelihood" bars not displaying properly; wider screen aspect ratios).
- Docs: noted that `tools/build-client-pack.py` and the `redscript/` source are not shipped in this package.
- Note: the manifest declares 0.4.0, but this changelog has no entries for 0.3.3 through 0.4.0 (native HUD pack, vitals, HUD element registry). See `docs/NATIVE-HUD.md`, `docs/HUD-ELEMENTS.md` and `docs/survival-vitals.md` for what shipped.
- Removed RPCore controller B map opening so B stays available for game/menu close and vehicle-exit behavior; use M or /rpcore.map to open it.
- Added `/rpcore.map.minimap on` to enable the player's native minimap setting and report its effective HUD visibility and active perspective.
- Set the rebindable map default to M and added `/rpcore.map.minimap` visibility diagnostics for the native game minimap.
- Clarified that the game renders the map and native pins; RPCore only adds its native pins and Locations tab.
- Aligned the runtime-reported RPCore version with the resource manifest.

## 0.3.2
- Added a rebindable X default and `/rpcore.map` toggle that opens the native City Map and selects RPCore Locations.

- Reported map-open failures and tracked native map ownership so RPCore only closes sessions it opened.

## 0.3.1
- `/rpcore.map` now opens the native City Map directly to RPCore's Locations tab when available.
- Added the native map ready handshake and diagnostics for map open and tab failures.

## 0.3.0 — native map integration

- Added an RPCore Locations tab to Open77's native City Map, using the game's actual map surface and saved RPCore locations.
- Added route actions for saved places and `/rpcore.map` to open the native map.
- Added an admin-only draggable map pin editor; admins can name pins, choose a native symbol, and save the current position.
- Checked pin creation against EventCore's Warden-backed admin status and stored shared pins through EventCore.
- Added explicit storage-error feedback when EventCore persistence or database access is unavailable.
- Added the Open77 `map.read` and `map.control` permissions required by native map tabs.

## 0.2.5 — map locations

- Added persistent, routable native map locations stored through EventCore.
- Added Warden-checked commands to add the current position, list locations, and remove locations.
- Required EventCore 0.5.0 storage and Open77's native map-pin permission.

## 0.2.4 — test build

- Integrated the player-facing HUD into RPCore and routed server-owned state through EventCore.
- Added provider handlers so other mods can supply survival values and extend the HUD without modifying RPCore.

## 0.2.3

- Added EventCore/Warden global-admin checks to RPCore's restricted server commands.
- Updated the EventCore minimum version for the trusted `IsAdmin` API.

## 0.2.2

- Restored RPCore health and vitals panels hidden by a legacy test-server CSS rule.
- Removed server branding from the HUD footer and obsolete logo UI messages.

## 0.2.1

- Raised the RPCore HUD WebUI above the OPX HUD layer while keeping the custom crosshair above it.
- Declared `ui.vanilla.hud` and hid the native health, stamina, and weapon widgets replaced by RPCore.
- Corrected admin ownership references: Warden/Open77 ACL remains authoritative, and the bundled `open77_admin` resource owns its panel and commands.

## 0.2.0-beta.2

- Added a server-side HUD snapshot publisher using Open77 player identity, life state, and vitals.
- Routed HUD snapshots through EventCore's versioned `rpcore.hud` client-state feed.
- Removed the synchronous client-state export read and its HUD load-order requirement.
- Renamed the HUD entry scripts and moved the shared HUD state API under `RPCore.Hud`.
- Recorded outstanding domain-provider and spawn work; admin controls remain a separate security-reviewed migration.
