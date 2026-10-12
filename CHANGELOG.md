# RPCore 0.4.0 Changelog

## 0.4.0 — native HUD and dynamic controls (development/playtest build)

Playtesting is incomplete; this build is not ready for general release. The notes below describe features present in the supplied 0.4.0 package and distinguish them from planned integrations.

### Added

- Added a required redscript client patch that carries EventCore-fed hunger, thirst, and cyberpsychosis data into the client's native HUD/`inkWidget` path instead of rendering those bars in a WebView.
- Documented the required mod's job: bridge EventCore-fed RPCore HUD state from the client Lua/RTTI path into Cyberpunk's native HUD controller and `inkWidget` system; event rules remain server/provider responsibilities.
- Added the `rtti.native` permission declaration and `/rpcore.hud.native` / `/rpcore.hud.native.ping` diagnostics for the Lua-to-redscript bridge.
- Added EventCore-fed vitals and psychosis state, including tier calculation, temporary tier/level overrides, timed visibility controls, expiry behavior, and provider-facing exports.
- Added an EventCore client-state channel for per-player HUD element visibility, opacity, and supported panel placement controls.
- Added Warden live tunables for native HUD enablement, psychosis tier thresholds and hysteresis, relic-effect settings, and override lifetimes.
- Added a launcher-delivered `preload_mod` client package with a SHA-256 file for Warden review; included server configuration guidance for required mods.
- Added a Freeroam HUD patch to prevent duplicate HUD behavior and an optional Freeroam kill-feed patch; clarified respawn-resource requirements.
- Retained the existing roleplay activity HUD, custom panels, journal, weapon card, crosshair, blood overlay, and native map locations/pins.

### Known limits and work still in progress

- RPCore supplies HUD display and control; it does not orchestrate RP events. The current EventCore build does not yet contain the complete logic to trigger damage red-screening, Blackwall static during netrunning, or consequences for failed or imperfectly completed tasks.
- The native meter is `psychosis`; `sanity` remains a deprecated compatibility alias. The relic effect's player-facing name is under revision; the current implementation targets a vanilla Johnny-sickness effect that Open77 multiplayer policy may suppress.
- The scripted bars cannot create a Blackwall ink effect at runtime, so that visual effect may be absent until a compatible widget/effect is available.
- Project playtesting has not completed. The operator-reported issues are vanilla health/lifelihood bars not displaying properly and incorrect wider-aspect-ratio layout. See `rpcore/docs/NATIVE-HUD.md` for other integration caveats.

## 0.3.2

- Added a rebindable map key and `/rpcore.map` to open the native City Map and select RPCore Locations.
- Reported map-open failures and tracked native map ownership so RPCore only closes sessions it opened.
- Added EventCore-backed persistent native map locations, admin pin editing, and the Locations tab.

## 0.3.1

- Added a native map ready handshake and diagnostics for map open and tab failures.

## 0.3.0 — native map integration

- Added an RPCore Locations tab to Open77's native City Map, using the game's map surface and saved RPCore locations.
- Added route actions for saved places and `/rpcore.map` to open the native map.
- Added an admin-only draggable map pin editor and EventCore-backed shared storage.
- Added Open77 `map.read` and `map.control` permissions for native map tabs.
