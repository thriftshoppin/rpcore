# Changelog

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
