# RPCore HUD migration plan — 0.2.0-beta.1

## Direction

RPCore becomes the updated home for the existing SIM: Night City HUD. The move preserves its behavior and presentation while adding RPCore's activity HUD and EventCore connection. It must not leave a second copy of the old HUD running beside it.

## Preserve from the current server assets

- Character, money, job, needs, humanity, weather, and HUD visibility from `simnc_core`'s `SimncState`.
- Health, armor, and stamina; weapon card and ammunition; third-person crosshair; blade-hit blood overlay; sounds, existing keybind behavior, and screen/menu visibility rules.
- Existing RPCore activity offers, accept/decline, objective tracking, completion/reward state, journal, server commands, and consumer exports.
- The server's existing administrator panel and its authorization rules, which are part of `simnc_core` in the supplied archive. `simnc_core` stays loaded, unchanged; the RPCore player controls menu does not replace or absorb its privileged admin tools.

The SIMNC-specific character and vitals reader remains an optional compatibility adapter in RPCore. RPCore's activity transport, service discovery, and future domain integrations use EventCore's versioned server API. This keeps the common framework usable outside SIMNC while the server-specific providers are migrated in stages.

## Stage 1 — runtime and input foundation

- Upgrade the existing RPCore 0.1.1 resource in a separate working copy to 0.2.0-beta.1.
- Add the Open77 `eventcore >=0.3.0-beta.1` dependency and route RPCore presentation messages through EventCore's `EmitClient` export.
- Add an EventCore handshake, service catalog cache, trusted player-context/observer calls, and a provider-call helper. Keep activity decisions server-authoritative.
- Move the existing SIMNC HUD scripts and web assets into the RPCore resource; update resource lifecycle checks and paths, preserve original display behavior, and remove `simnc_hud` from the supplied load-order overlay to avoid duplicate surfaces.
- Register rebindable actions for settings, accept, decline, action, journal, and HUD visibility, with defaults checked against the supplied server resource tree.
- Add an in-game RPCore control panel with a keybind cheat sheet and per-action rebind/reset controls using Open77's persistent key mapping API.
- Keep the existing server admin panel and its ACL boundaries untouched.

## Stage 2 — server-owned HUD data contracts

- Add domain providers to EventCore for server-authoritative character, inventory, appearance/outfit, mission, and other state only when the resource that owns each domain exposes and validates that service.
- Have RPCore consume advertised services and send only the player-safe view needed by the HUD.
- Route other-player appearance updates only to EventCore's current observer scope.
- Retire the temporary SIMNC compatibility reader only after the replacement provider produces matching data and behavior in game.

## Stage 3 — persistence and validation

- Persist authoritative activity transitions and player state through EventCore's server-only persistence API.
- Reconcile restored activity/journal state with the HUD without changing the established player-facing flow.
- Verify load order, Warden permissions, rebinding persistence, visual parity, and event routing on the actual Open77 server.

## Release boundaries

- This stage prepares the HUD/resource and EventCore transport; it does not claim in-game verification.
- The SIMNC HUD sources are moved under RPCore; `simnc_core` remains loaded as the temporary source of its existing player-data contract. `simnc_hud` must be removed from the server load list once the migrated RPCore surfaces are enabled.
- Inventory, outfit, mission, and health providers are not invented in RPCore when their authoritative owners do not expose them through EventCore yet.
- The input key defaults are test defaults, not a requirement that players keep them. All RPCore bindings remain individually rebindable in the custom panel and in Open77's standard key-binding settings.
