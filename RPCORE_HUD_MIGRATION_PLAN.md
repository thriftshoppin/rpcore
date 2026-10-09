# RPCore HUD and roleplay framework migration plan

## Direction

RPCore owns the player HUD and roleplay activity interface. The vitals surface uses compact, individually adjustable perspective bars. Platform-backed values render immediately; optional survival and roleplay values appear when an authorized provider supplies them. The Freeroam HUD can be hidden independently while its gameplay remains available.

## Current foundations

- EventCore transports versioned, client-safe HUD state and provides approved persistence.
- RPCore renders platform identity, life state, and vitals, plus provider-backed hunger, thirst, and sanity values.
- RPCore includes activity offers, tracking, results, a journal, settings, panel layout, weapon display, crosshair, damage overlay, and persistent native map locations.
- Warden remains the authority for global roles and command grants. EventCore owns the framework administrator entry point and checks access before exposing tools.
- Resource-to-resource integrations use their domain owners first and EventCore's approved services and storage where needed.

## Next development stages

### Domain providers

- Establish server-authoritative providers for character, economy, jobs, needs, humanity, weather, and spawn behavior.
- Publish only client-safe presentation data through EventCore.
- Route other-player appearance updates only to Open77's current observer scope.

### Administration

- Continue moving useful administrative workflows into EventCore while retaining Warden/Open77 authorization checks.
- Keep each gameplay action implemented and validated by its owning resource until that action has a reviewed EventCore integration.

### Persistence and release validation

- Persist authoritative activity transitions and player state through EventCore's trusted storage API.
- Reconcile restored activity and journal state with the HUD.
- Verify load order, Warden permissions, input rebinding, map persistence, visual behavior, and event routing on the Open77 test server.

## Boundaries

- The HUD state feed is implemented; behavior still requires in-game verification for each target server build.
- Activity history remains in memory until its persistence work is completed.
- Inventory, outfits, missions, and health remain authoritative in their domain resources; EventCore is the approved compatibility and persistence layer where direct integration does not fit.
- Key defaults are configurable test defaults, not requirements for players.
