# RPCore 0.4.0 — server resource checkpoint

## Status

Development/playtest build; project playtesting is incomplete. Install and verify this resource together with the repository-root `rpcore-hud/` required-mod package.

## Implemented in this resource

- Open77 server resource manifest requires EventCore 0.6.1 or newer and declares the launcher-delivered `dist/rpcore-hud.zip` client mod.
- EventCore adapter publishes HUD state and accepts validated trusted provider calls.
- Vitals/psychosis state, tier logic, temporary overrides, visibility controls, HUD element registry/control, and Warden tunables are present.
- Roleplay activity presentation, custom panels, journal, weapon/crosshair/blood surfaces, and native map locations/pins remain included.
- Freeroam duplicate-HUD and optional kill-feed patches are under `install/`.

## Integration still in progress

- The client redscript bridge and game's native HUD/`inkWidget` path require the separate required-mod package and the Warden-approved `rtti.native` permission.
- EventCore does not yet orchestrate every planned damage red-screening, Blackwall/netrunning, or task-quality scenario. RPCore does not trigger those events itself.
- Playtesting remains incomplete; current reported display issues are vanilla health/lifelihood bars and wide-aspect-ratio layout.

## Operator verification before release

- Confirm EventCore and `open77_chat` load before RPCore, and `rpcore` is on EventCore's whitelist.
- Confirm Warden required-mod hash review and RPCore permissions.
- Join through the OPEN//77 launcher and check `/rpcore.status`, `/rpcore.hud.native`, and `/rpcore.hud.native.ping`.
- Complete in-game checks across supported aspect ratios and the planned event integrations.
