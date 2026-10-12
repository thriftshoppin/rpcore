# RPCore contributor handoff

Last verified: 2026-10-11, after an in-game test by the operator. Treat this file and `CHANGELOG.md` as current. Earlier statements that RPCore hides the native health/stamina/weapon widgets, or that the web vitals panel is on by default, are outdated.

## Current state

- Manifest version 0.4.0; requires `eventcore >=0.6.1` (EventCore 0.7.0 is what is installed). Load `eventcore` first and `rpcore` once.
- RPCore owns the player HUD. EventCore owns HUD writes (`server/hud.lua` in the EventCore repo); RPCore only accepts them from EventCore.
- HUD defaults: every native widget `default` is `nil` (RPCore hides nothing), all `webFallback` surfaces are `false`, and the hunger/thirst/sanity bars are drawn natively by the redscript pack in `dist/rpcore-hud.zip`.
- The required client source is in the repository-root `rpcore-hud/r6/scripts/RPCore/` folder. The server-delivered copy is `rpcore/dist/rpcore-hud.zip`; keep the source and package aligned and update both SHA-256 files after rebuilding. This repository does not include `tools/build-client-pack.py`.

## Repository layout

- Root `README.md`, `AGENTS.md`, `CHECKPOINT.md`, and `CHANGELOG.md` describe the combined project.
- `rpcore/` is the installable Open77 server resource and includes its own README and checkpoint.
- `rpcore-hud/` is the required client redscript patch source and includes its own README and checkpoint.
- Install the server resource and required client mod together; the top-level HUD source folder is for review and rebuilding, while `rpcore/dist/rpcore-hud.zip` is the launcher-delivered package.

## Server facts (confirmed against a real `server.jsonc`)

- Load `open77_chat`; EventCore chat depends on it.
- Only Freeroam and RPCore call `Open77.hud`. Apply `install/disable-freeroam-hud.patch` so Freeroam does not hide the game's HUD widgets; keep Freeroam loaded because it is the only stock resource that respawns players.
- Never keep an `rpcore/` folder nested inside the EventCore folder.
- `/rpcore.vanilla` and `/rpcore.hud.native` print to the client log and chat; other `[rpcore]` debug lines are client-log only.

## Known issues (operator-reported, in-game tested 2026-10-11)

- Vanilla health and "lifelihood" bars do not display properly.
- Wider screen aspect ratios display incorrectly.
- These are known issues, not configuration errors. Do not change `shared/config.lua` or server setup to chase them without the operator asking. No other issues were reported in that test.

## Release

- The operator makes the git commits. Do not commit, push, or deploy.
- Licensing is staged by the operator: all rights reserved while the software is in development, MIT from the full release onward. This package has no `LICENSE` file yet. Do not add one, add MIT text or headers, or state license terms in docs until the operator announces the full release.
