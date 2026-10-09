# RPCore migration checkpoint — development build

## Current status

- The package includes compact vitals, provider-backed hunger/thirst/sanity rows, and adjustable HUD panels.
- This is a development snapshot, not a public release. No release archive or GitHub release has been created.
- Persistent map locations and the HUD require in-game verification on the target Open77 build.

## Implemented

- Compact individual glass bars and provider interfaces for survival values.
- Cyberpsychosis/Blackwall treatment on the sanity bar.
- Per-player drag editor for RPCore panels, alongside activity, weapon, crosshair, damage overlay, and controls surfaces.
- HUD snapshots and activity presentation routed through EventCore.
- RPCore restricted server commands consult EventCore's trusted admin check; Warden remains authoritative for global roles.
- Server-specific logo/footer branding removed and duplicate Freeroam HUD suppression documented.

## Remaining verification and development work

- Confirm perspective, size, color, and panel placement in game.
- Verify EventCore delivery, Warden permissions, key rebinding, and provider updates.
- Connect an authoritative needs provider; RPCore intentionally does not simulate hunger, thirst, or sanity.
- Add providers for economy, jobs, humanity, weather, character login, and spawn behavior.
- Continue admin action migration with authorization checks intact.

## Artifacts

- Working resource: `rpcore/`.
- Install/load-order example: `rpcore/install/server-load-order.jsonc`.
- HUD provider contract: `rpcore/docs/survival-vitals.md`.
