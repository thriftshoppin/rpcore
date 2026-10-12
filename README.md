# RPCore 0.4.0

**Development/playtest build. Playtesting is incomplete; this is not a finished general-release package.**

<u>**You must own a valid copy of Cyberpunk 2077 and Phantom Liberty to download and use these modifications.**</u> See the required HUD mod's [project use terms](rpcore-hud/README.md#project-use-terms).

RPCore 0.4.0 is delivered as two coordinated parts: the Open77 server resource in [`rpcore/`](rpcore/) and the client-side native HUD bridge source in [`rpcore-hud/`](rpcore-hud/). They are intended to be installed together. EventCore carries server state to RPCore; the required redscript patch bridges RPCore's client HUD data into Cyberpunk's native client HUD/`inkWidget` path. The HUD bars use native-game presentation rather than a WebView HUD.

RPCore provides the server side: trusted provider exports, validation, EventCore state delivery, HUD controls and roleplay interfaces. The required mod provides the client side of the HUD data path. It does not decide when RP events happen. EventCore does not yet include the complete event logic for planned damage red-screening, Blackwall netrunning interference, or failed/imperfect-task outcomes.

## Repository layout

- [`README.md`](README.md) — project overview and combined install guide.
- [`AGENTS.md`](AGENTS.md) — contributor and repository structure notes.
- [`CHECKPOINT.md`](CHECKPOINT.md) — overall development and integration status.
- [`CHANGELOG.md`](CHANGELOG.md) — RPCore 0.4.0 package changes and current limits.
- [`rpcore/`](rpcore/) — installable Open77 server resource. Its `dist/rpcore-hud.zip` is the required client mod delivered by the launcher.
- [`rpcore-hud/`](rpcore-hud/) — extracted redscript source for the required mod, preserving the `r6/scripts/RPCore/` path, plus checksum and mod-specific docs.

## Install both parts

1. Install EventCore **0.6.1 or newer** and `open77_chat`. Add `rpcore` to EventCore's `server/whitelist.lua`.
2. Copy the `rpcore/` directory into the Open77 server's `resources/` folder. In `server.jsonc`, load `eventcore`, `open77_chat`, then `rpcore`; enable `requiredMods`.
3. In Warden, review/approve the exact hash in `rpcore/dist/rpcore-hud.zip.sha256` and approve RPCore's requested permissions, especially `rtti.native`. If the required-mod archive is rebuilt, its hash changes and must be reviewed again. `requiredMods.unsecured: true` is an alternative only when intentionally allowing unsecured required mods.
4. Players connect through the OPEN//77 launcher. It installs the required `rpcore-hud.zip` before the game starts. The top-level `rpcore-hud/` directory is the source for review and rebuilding; it is not a second Open77 server resource to copy into `resources/`.
5. Check `/rpcore.status` on the server and `/rpcore.hud.native` plus `/rpcore.hud.native.ping` on one test client before wider playtesting.

For component-specific installation, feature details, and limitations, see [`rpcore/README.md`](rpcore/README.md) and [`rpcore-hud/README.md`](rpcore-hud/README.md).
