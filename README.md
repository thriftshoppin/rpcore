# RPCore

**RPCore 0.3.1 development build — EventCore-ready roleplay HUD and activity framework for Open77.**

RPCore is the home for the Open77 player-facing HUD and RP activity interface; EventCore owns the state transport contract. The project is intended to remain open source and free for anyone to use and modify. This is a development build; publication terms and licensing will be stated with the public release.

## Repository layout

- [`rpcore/`](rpcore/) — installable Open77 resource, including its manifest, client/server scripts, HUD assets, and install notes.
- [`RPCORE_HUD_MIGRATION_PLAN.md`](RPCORE_HUD_MIGRATION_PLAN.md) — staged architecture and follow-up work.
- [`CHECKPOINT.md`](CHECKPOINT.md) — implemented scope and items needing in-game verification.

## Install

Copy the `rpcore/` folder into the server's `resources/` directory. Install EventCore 0.6.1 or newer, then load `eventcore` before `rpcore`. Add `rpcore` to EventCore `server/whitelist.lua`. Remove any competing HUD resource to avoid duplicate widgets. See [`rpcore/README.md`](rpcore/README.md) and [`rpcore/install/server-load-order.jsonc`](rpcore/install/server-load-order.jsonc) for details.

The player HUD, weapon card, third-person crosshair, blood overlay, RPCore activity UI, persistent native map locations, and a Locations tab in the native City Map are included. The game renders the map itself; RPCore adds persistent pins and a routeable saved-location list. Platform identity, life state, and vitals are published through EventCore. Providers for economy, jobs, needs, humanity, weather, and spawn behavior remain future work. EventCore owns the admin entry point; Warden remains authoritative for global roles and command grants.

## Release status

This is a development package. Map persistence, provider delivery, Warden permissions, resource activation, key rebinding, and HUD behavior need verification in game before release. Open77 currently exposes native map visibility and custom full-screen map tabs, but no supported minimap reposition/texture API; this build uses the native City Map rather than drawing a fabricated map in the HUD.
