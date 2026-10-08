# RPCore

**EventCore-ready roleplay HUD and activity framework for Open77.**

This repository contains the 0.2.0-beta.1 HUD migration package. RPCore is the updated home for the existing SIM: Night City HUD: this release moves its existing player-facing display into RPCore while connecting RPCore activity presentation to EventCore.

## Repository layout

- [`rpcore/`](rpcore/) — installable Open77 resource, including its manifest, client/server scripts, HUD assets, and install notes.
- [`RPCORE_HUD_MIGRATION_PLAN.md`](RPCORE_HUD_MIGRATION_PLAN.md) — staged architecture and follow-up work.
- [`CHECKPOINT.md`](CHECKPOINT.md) — implemented scope and items needing in-game verification.

## Install

Copy the `rpcore/` folder into the server's `resources/` directory. Install EventCore 0.3.0-beta.1 or newer, then load `eventcore` before `rpcore`. Keep `simnc_core` loaded before RPCore for the current compatibility reader, and remove `simnc_hud` after enabling the migrated resource to avoid duplicate HUDs. See [`rpcore/README.md`](rpcore/README.md) and [`rpcore/install/server-load-order.jsonc`](rpcore/install/server-load-order.jsonc).

The SIMNC character/vitals panel, weapon card, third-person crosshair, blood overlay, and RPCore activity UI are included. The admin panel remains in `simnc_core` with its existing access controls.

## Release status

This is a beta source package. Static review and packaging are complete; resource activation, EventCore delivery, HUD parity, and key rebinding still need verification on an Open77 server and in game. Inventory/outfit providers and durable RPCore player state are future integration work.
