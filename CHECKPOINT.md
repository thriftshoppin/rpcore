# RPCore migration checkpoint — development build

## Current status

- The package includes compact vitals, provider-backed hunger/thirst/sanity rows, and adjustable HUD panels.
- RPCore 0.3.1 / EventCore 0.6.1 are the current local revisions; verify chat and map behavior in game before a remote release.
- Native-map tab activation, EventCore chat input/command forwarding, storage availability, and HUD behavior still require in-game verification.

## Implemented

- Compact individual glass bars and provider interfaces for survival values.
- Cyberpsychosis/Blackwall treatment on the sanity bar.
- Per-player drag editor for RPCore panels, alongside activity, weapon, crosshair, damage overlay, and controls surfaces.
- HUD snapshots and activity presentation routed through EventCore.
- RPCore restricted server commands consult EventCore's trusted admin check; Warden remains authoritative for global roles.
- RPCore adds a saved-locations tab to Open77's native City Map and creates persistent, routable native blips from EventCore storage.
- EventCore provides a skinnable chat panel and routes slash commands through Open77's existing client/server command path.
- Server-specific logo/footer branding removed and duplicate Freeroam HUD suppression documented.

## Remaining verification and development work

- Confirm perspective, size, color, and panel placement in game.
- Verify EventCore delivery, Warden permissions, key rebinding, and provider updates.
- Remove `open77_chat` from the server resource list when adopting EventCore's replacement UI and T binding; leave other resources and their command registrations enabled.
- Enable database persistence and approve EventCore/RPCore map permissions before validating saved locations and routing.
- Connect an authoritative needs provider; RPCore intentionally does not simulate hunger, thirst, or sanity.
- Add providers for economy, jobs, humanity, weather, character login, and spawn behavior.
- Continue admin action migration with authorization checks intact.

## Artifacts

- Working resource: `rpcore/`.
- Install/load-order example: `rpcore/install/server-load-order.jsonc`.
- HUD provider contract: `rpcore/docs/survival-vitals.md`.
- Chat migration guide: `../eventcore/docs/chat.md`.
