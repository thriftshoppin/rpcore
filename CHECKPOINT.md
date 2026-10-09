# RPCore migration checkpoint — 0.2.4 test build

## Current status

- The local package includes the compact vitals HUD, provider-backed hunger/thirst/sanity rows, and a subtle perspective tilt on the vitals bars.
- The test server has the previously deployed HUD perspective version. This revision simplifies the effect to a subtle tilt on the vitals bars; it has not been deployed or reviewed in game yet.
- This is a development snapshot, not a public release. No release archive or GitHub release has been created.
- Version metadata is aligned at `0.2.4` in the resource manifest and RPCore runtime.

## Implemented

- Replaced the oversized test-server vitals presentation with compact individual glass bars and provider-backed survival values.
- Added the cyberpsychosis/Blackwall treatment to the sanity bar; external resources supply and retain hunger, thirst, and sanity values through the documented RPCore exports.
- Added the per-player drag editor for RPCore HUD panels and retained existing activity, weapon, crosshair, blood, and controls surfaces.
- Routed HUD snapshots and activity presentation through EventCore; RPCore's restricted server commands also consult EventCore's trusted admin check while Warden remains authoritative for global roles.
- Removed server-specific logo/footer branding and documented suppression of the competing Freeroam HUD surface.

## Remaining verification and migration work

- Reload the test server and confirm the reversed perspective and panel placement in game.
- Verify EventCore feed delivery, Warden permissions, key rebinding, and provider updates in the target Open77 build.
- Connect a needs resource to provide hunger, thirst, and sanity values; those systems are intentionally not simulated by RPCore.
- SIMNC-specific money, job, humanity, weather, character login, and spawn behavior are not claimed as migrated.
- EventCore owns the admin entry point, while additional admin action handlers remain subject to separate review.

## Artifacts

- Working source: this repository's `rpcore/` resource.
- Install/load-order example: `rpcore/install/server-load-order.jsonc`.
- HUD provider contract: `rpcore/docs/survival-vitals.md`.
