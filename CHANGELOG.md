# Changelog

## Unreleased

- Shortened the vitals bars, removed meter tick dividers, softened the green glass tint, thickened the rails, and gave the HUD a perspective tilt.
- Reduced the vitals HUD scale from 78% to 45% and migrated saved vitals-panel scales by the same ratio so prior layout settings do not override the smaller default.
- Added HUNGER, THIRST, and SANITY bars with a red Blackwall effect that intensifies as cyberpsychosis severity rises; added the `SetSurvivalVitals` and `ClearSurvivalVitals` provider exports.
- Reduced the vitals HUD footprint and aligned its backing rail with the green accent.
- Added a per-player layout editor for the vitals and occupation HUD, activity panels, journal, controls, and weapon readout; panels drag independently and save their positions on that client.
- Replaced the ring-and-card vitals page with a compact, perspective-tilted HUD of individual glass bars; stamina is green and water is blue, with no server logo or footer branding.
- Added optional level, breath, food, and water values to the HUD adapter; unavailable fields remain hidden rather than displaying fabricated readings.
- Added a deployment patch to suppress only Freeroam's competing HUD surface while retaining its gameplay and scoreboard.

## 0.2.3

- Added EventCore/Warden global-admin checks to RPCore's restricted server commands.
- Updated the EventCore minimum version for the trusted `IsAdmin` API.

## 0.2.2

- Restored RPCore health and vitals panels hidden by a legacy test-server CSS rule.
- Removed the SIMNC-specific logo and obsolete logo UI messages.

## 0.2.1

- Raised the SIMNC HUD WebUI above the OPX HUD layer while keeping the custom crosshair above it.
- Declared `ui.vanilla.hud` and hid the native health, stamina, and weapon widgets replaced by RPCore.
- Corrected admin ownership references: Warden/Open77 ACL remains authoritative, and the bundled `open77_admin` resource owns its panel and commands.

## 0.2.0-beta.2

- Added a server-side HUD snapshot publisher using Open77 player identity, life state, and vitals.
- Routed HUD snapshots through EventCore's versioned `rpcore.hud` client-state feed.
- Removed the synchronous `simnc_core:SimncState` client read and its HUD load-order requirement.
- Renamed the HUD entry scripts and moved the shared HUD state API under `RPCore.Hud`.
- Recorded remaining SIMNC domain and spawn migration work; admin controls remain a separate security-reviewed migration.
