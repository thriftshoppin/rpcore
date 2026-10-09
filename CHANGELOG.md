# Changelog

## 0.2.0-beta.2

- Added a server-side HUD snapshot publisher using Open77 player identity, life state, and vitals.
- Routed HUD snapshots through EventCore's versioned `rpcore.hud` client-state feed.
- Removed the synchronous `simnc_core:SimncState` client read and its HUD load-order requirement.
- Renamed the HUD entry scripts and moved the shared HUD state API under `RPCore.Hud`.
- Recorded remaining SIMNC domain and spawn migration work; admin controls remain a separate security-reviewed migration.
