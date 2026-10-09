# RPCore

**RPCore 0.2.4 development build — EventCore-ready roleplay HUD and activity framework for Open77.**

This repository contains the 0.2.4 HUD iteration. RPCore is the home for the SIM: Night City player-facing HUD and RP activity interface; EventCore owns the state transport contract. The test-bench build has been visually reviewed, but this remains a development build rather than a public release.

## Repository layout

- [`rpcore/`](rpcore/) — installable Open77 resource, including its manifest, client/server scripts, HUD assets, and install notes.
- [`RPCORE_HUD_MIGRATION_PLAN.md`](RPCORE_HUD_MIGRATION_PLAN.md) — staged architecture and follow-up work.
- [`CHECKPOINT.md`](CHECKPOINT.md) — implemented scope and items needing in-game verification.

## Install

Copy the `rpcore/` folder into the server's `resources/` directory. Install EventCore 0.3.1 or newer, then load `eventcore` before `rpcore`. Remove `simnc_hud` after enabling the migrated resource to avoid duplicate HUDs. RPCore no longer calls `simnc_core`; remaining SIMNC-owned features are being migrated in later steps. See [`rpcore/README.md`](rpcore/README.md) and [`rpcore/install/server-load-order.jsonc`](rpcore/install/server-load-order.jsonc).

The migrated character/vitals panel, weapon card, third-person crosshair, blood overlay, and RPCore activity UI are included. This step publishes platform identity/life/vitals through EventCore; money, job, needs, humanity, weather, and the spawn system remain to be migrated. The admin panel remains in its existing resource pending a separate security-reviewed migration.

## Release status

This is a beta development package. The test server has the prior HUD perspective version; this revision simplifies the effect to a subtle tilt on the vitals bars and has not been deployed or reviewed in game yet. Provider delivery, Warden permissions, resource activation, key rebinding, and full HUD parity still need verification. SIMNC's remaining domain and spawn behavior are future migration work.
