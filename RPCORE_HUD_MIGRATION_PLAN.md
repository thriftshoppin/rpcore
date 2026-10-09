# RPCore HUD migration plan — 0.2.0-beta.2

## Direction

RPCore becomes the updated home for the existing SIM: Night City HUD. The move preserves its behavior and presentation while adding RPCore's activity HUD and EventCore connection. It must not leave a second copy of the old HUD running beside it.

## Preserve from the current server assets

- Character, money, job, needs, humanity, weather, and HUD visibility from `simnc_core`'s `SimncState`.
- Health, armor, and stamina; weapon card and ammunition; third-person crosshair; blade-hit blood overlay; sounds, existing keybind behavior, and screen/menu visibility rules.
- Existing RPCore activity offers, accept/decline, objective tracking, completion/reward state, journal, server commands, and consumer exports.
- The server's existing administrator panel and its authorization rules, which are part of `simnc_core` in the supplied archive. `simnc_core` stays loaded, unchanged; the RPCore player controls menu does not replace or absorb its privileged admin tools.

RPCore has removed the direct SIMNC client export read. EventCore owns the versioned client-state transport, and RPCore currently publishes Open77 platform identity, life state, and vitals. SIMNC-specific money, job, needs, humanity, weather, spawn, and character-session behavior remains migration work. This keeps the framework usable outside SIMNC while those domains are moved in stages.

## Stage 1 — runtime and input foundation

- Completed in 0.2.0-beta.1: upgrade the existing RPCore resource, add the EventCore dependency, and route activity presentation through EventCore.
- Completed in 0.2.0-beta.2: add the EventCore `rpcore.hud` state-feed publisher/consumer and remove the direct `simnc_core:SimncState` client read.
- Add an EventCore handshake, service catalog cache, trusted player-context/observer calls, and a provider-call helper. Keep activity decisions server-authoritative.
- Move the existing SIMNC HUD scripts and web assets into the RPCore resource; update resource lifecycle checks and paths, preserve original display behavior, and remove `simnc_hud` from the supplied load-order overlay to avoid duplicate surfaces.
- Register rebindable actions for settings, accept, decline, action, journal, and HUD visibility, with defaults checked against the supplied server resource tree.
- Add an in-game RPCore control panel with a keybind cheat sheet and per-action rebind/reset controls using Open77's persistent key mapping API.
- Keep the existing server admin panel and its ACL boundaries untouched.

## Stage 2 — migrate remaining SIMNC-owned HUD data

- Move or replace character, economy, needs, humanity, weather, and spawn sources with server-authoritative RPCore/EventCore contracts, preserving their observed behavior.
- Have RPCore publish only the player-safe view needed by the HUD.
- Route other-player appearance updates only to EventCore's current observer scope.
- Verify each replacement in game before removing its SIMNC source.

## Stage 3 — persistence and validation

- Persist authoritative activity transitions and player state through EventCore's server-only persistence API.
- Reconcile restored activity/journal state with the HUD without changing the established player-facing flow.
- Verify load order, Warden permissions, rebinding persistence, visual parity, and event routing on the actual Open77 server.

## Release boundaries

- The HUD feed transport is implemented, but no in-game verification is claimed.
- `simnc_hud` can be removed after migration to avoid duplicate surfaces. `simnc_core` remains temporarily for domains and admin tools not yet migrated; RPCore no longer reads its HUD client export.
- Inventory, outfit, mission, and health providers are not invented in RPCore when their authoritative owners do not expose them through EventCore yet.
- The input key defaults are test defaults, not a requirement that players keep them. All RPCore bindings remain individually rebindable in the custom panel and in Open77's standard key-binding settings.
