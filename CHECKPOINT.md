# RPCore 0.4.0 — project checkpoint

## Status

This package is in development and project playtesting is incomplete. It is not ready for general release. Treat the server resource and required client mod as a combined integration; testing one without the other does not verify the native HUD path.

## Included components

- `rpcore/`: Open77 server resource with EventCore integration, provider exports, native HUD snapshots/control, roleplay UI, and the required-mod preload declaration.
- `rpcore-hud/`: source for the required redscript client patch, with the original `r6/scripts/RPCore/` hierarchy and the supplied SHA-256 file.
- The server resource includes its launcher-delivered client package at `rpcore/dist/rpcore-hud.zip` and matching `rpcore/dist/rpcore-hud.zip.sha256`.

## Integration status

- EventCore-fed HUD data can be carried by RPCore toward the client's native HUD bridge.
- The redscript patch is the client-side handoff to the game's HUD controller and `inkWidget` system; those widgets use the native game HUD path instead of a WebView surface.
- The current EventCore build does not yet orchestrate all planned damage, Blackwall/netrunning, or task-quality scenarios. RPCore does not invent or trigger those events.
- Project playtesting is not complete. See the component-specific checkpoints for known display and integration limits.

## Before release

Review the exact required-mod hash in Warden, approve the declared RPCore permissions, verify the combined launcher install, and complete playtesting for supported game/client configurations. Re-review any rebuilt client package whose hash changes.
