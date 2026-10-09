# Changelog

## Unreleased
- Added `/rpcore.map.minimap on` to enable the player's native minimap setting and report its effective HUD visibility and active perspective.
- Set the rebindable map default to M and added `/rpcore.map.minimap` visibility diagnostics for the native game minimap.
- Clarified that the game renders the map and native pins; RPCore only adds its native pins and Locations tab.
- Aligned the runtime-reported RPCore version with the resource manifest.

## 0.3.2
- Added a rebindable X default and `/rpcore.map` toggle that opens the native City Map and selects RPCore Locations.
- Added controller B to open the native map when closed; the native map retains B for its own back/close behavior.
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
