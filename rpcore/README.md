# RPCore HUD and player experience

RPCore owns the player-facing HUD and the server-agnostic RP activity HUD. Its compact vitals use separate, color-coded glass bars with a subtle perspective tilt. Health, stamina, and armor come from Open77. Hunger, thirst, and sanity bars accept values from another server resource; higher sanity severity shifts the bar red and adds Blackwall interference. Level and breath rows remain optional. RPCore also provides a weapon card, crosshair, blood overlay, activity offers, tracker, journal, developer commands, consumer exports, persistent native map pins, and a Locations tab in Open77's native City Map. The game supplies the map surface; RPCore lists saved places and routes through native pins. It is intended to remain open source and free for anyone to use and modify. Publication terms and licensing will be stated with the public release.

RPCore's restricted server commands query EventCore's trusted `IsAdmin` API in
addition to Open77's command permission. Warden continues to own global roles
and command grants.

Use `/rpcore.layout` or press the configurable **F9** binding to arrange RPCore's HUD panels. Drag a panel to move it, switch between Vitals, Activities, and Weapon from the editor toolbar, then choose **Done**. Each panel position is saved per player. **Reset panel** restores the last moved panel to its default position.

## Install and load order

1. Copy this `rpcore/` folder into the server's `resources/` folder.
2. Install EventCore 0.6.0 or newer into the same resources root. Add `rpcore` to EventCore `server/whitelist.lua`.
3. In `server.jsonc`, put `eventcore` before `rpcore`. Remove any other resource that creates duplicate HUD widgets. On servers that run the bundled Freeroam gamemode, apply [`install/disable-freeroam-hud.patch`](install/disable-freeroam-hud.patch) from the server root so Freeroam keeps its gameplay and scoreboard but does not create a second player HUD. Keep unrelated gameplay resources enabled when they provide services used by other installed resources.
4. Restart the server. Confirm both resources start without errors; `/rpcore.status` reports the EventCore connection.
5. In game, use `/rpcore.demo` to see the activity HUD. Press **F6** for RPCore Controls. Accept **F7**, decline **F11**, action **F12**, journal **Insert**, HUD visibility **Home**, and arrange panels **F9** are test defaults. Change or reset each binding in the panel or the game's key-binding settings.

RPCore requests `ui.vanilla.hud` to hide the native health, stamina, and weapon widgets that its HUD replaces, `ui.vanilla.map` to create native map pins, and `map.read`/`map.control` for its native-map Locations tab. Approve those permissions in Warden. Its HUD surface uses z-index 800, above the OPX HUD at 700 and below RPCore's crosshair at 850.

Open the map with the normal game binding or `/rpcore.map`. The built-in Map tab uses the game's map renderer and displays saved RPCore pins; the Locations tab lists saved places and offers native GPS routing. Admins can toggle the draggable **Edit pins** panel from that tab to save a named pin at their current position, choose its native symbol, and persist it through EventCore. Only EventCore/Warden admins receive permission to use the editor; saved places are shared. The symbol picker currently offers Objective, Tech, Danger, and Vehicle. Open77 does not currently expose a supported API for relocating or extracting the minimap texture into the always-visible HUD.

The supplied overlay at `install/server-load-order.jsonc` illustrates the two load-list edits. Merge them into the server's existing resource list; do not replace the server configuration with the overlay.

## Preserved HUD surfaces

- Perspective glass-bar HUD with health, stamina, armor, and optional provider-backed breath, food, water, and level rows. A separate occupation card appears when a job provider supplies the value.
- Weapon/ammunition card, third-person crosshair, and blade-hit blood overlay.
- Existing activity offer, accept/decline flow, objectives, results/rewards, journal, resource commands, and public consumer exports.
- A Locations tab in the native map screen, with saved-place list and route controls.
- An admin-only draggable map-pin editor for creating persistent, named pins with native symbols.
- F6 settings panel with the keybinding cheatsheet, per-action rebind, reset-to-test-default, and Escape close behavior.
- In-game drag editor for vitals, occupation, activity, journal, controls and weapon panels. Layout positions persist per player.
- Open77's bundled `open77_admin` resource remains the owner of the platform admin panel and its ACL-checked commands; RPCore does not replace or absorb those tools.

## EventCore integration

RPCore requires EventCore and discovers its runtime/service catalog through documented exports. Activity presentation is delivered through EventCore's `EmitClient` route. HUD snapshots are built from Open77 server identity, life state, and vitals, then published through EventCore's versioned state feed. A needs or character resource can call RPCore's `SetSurvivalVitals` server export to supply hunger, thirst, and sanity values; RPCore holds the latest supplied values in memory and renders them. See [`docs/survival-vitals.md`](docs/survival-vitals.md) for the payload and lifecycle contract. No provider is bundled, so those rows stay hidden until another resource supplies values.

## Important limits

- This is a development build, not a public release. The test server has the prior HUD perspective version; this revision's simpler tilt on the vitals bars has not been deployed or reviewed in game. HUD state delivery, Warden permissions, resource activation, key rebinding, and z-order still need verification.
- Only platform-backed identity, life state, and vitals are currently published. Providers for economy, jobs, needs, humanity, weather, and character state remain future work.
- RPCore activity history remains in memory in this beta. EventCore currently persists shared RPCore map locations; durable player inventory and outfit storage remain outside this package.
- Defaults are configurable and can be changed in RPCore controls or Open77 key-binding settings. F12 is also commonly used by platform software; rebind it if it conflicts on your setup.

## Contents

- `server/`: server-authoritative activity engine, EventCore adapter, and HUD snapshot publisher.
- `client/`: activity HUD, input menu, and RPCore HUD renderers.
- `web/`: RPCore activity HUD plus the RPCore HUD, images, fonts, weapon, crosshair, and blood layers.
- `install/server-load-order.jsonc`: small load-order merge example.
- `docs/CONSUMING.md`: RPCore activity API for other resources.
- `docs/survival-vitals.md`: provider API for hunger, thirst, and sanity bars.
