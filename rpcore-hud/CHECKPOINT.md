# RPCore 0.4.0 — required HUD mod checkpoint

## Status

The source package contains six redscript files under `r6/scripts/RPCore/` and a SHA-256 file for `rpcore-hud.zip`. The server-delivered copy is `rpcore/dist/rpcore-hud.zip`. This required mod only provides the client-side bridge into the native HUD/`inkWidget` path; EventCore and RPCore provide the server data and client handoff.

Project playtesting is incomplete. Do not treat the package as release-ready.

## Integration points

- RPCore's manifest declares the packaged client mod with `preload_mod`.
- RPCore client code uses the Warden-approved Open77 `rtti.native` bridge to send values/configuration to redscript endpoints.
- The patch forwards those updates to the game's native HUD controller/`inkWidget` path; the bars are not drawn by a WebView overlay.
- EventCore does not yet drive every planned damage, Blackwall/netrunning, or failed/imperfect-task event.

## Verification status and work remaining

- Confirm the exact deployed archive digest matches the Warden-reviewed digest after every rebuild.
- Complete first-client compile and in-game bridge checks through the OPEN//77 launcher.
- Validate the native widgets and effect behavior in multiplayer, including wide aspect ratios. Blackwall ink effects may be absent because the scripted bars cannot create a new ink effect at runtime; the current relic-effect target may be suppressed by multiplayer policy.
- Keep this folder, `rpcore/redscript/r6/`, the generated `rpcore/dist/rpcore-hud.zip`, and their checksum synchronized.
