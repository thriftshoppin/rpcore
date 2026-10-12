# RPCore 0.4.0 — required native HUD mod

> Development/playtest component. Project playtesting is incomplete; this is not a finished general-release mod.

This directory contains the source of RPCore's required redscript client patch, preserving the game path `r6/scripts/RPCore/`. It is designed to be used with the Open77 server resource at [`../rpcore/`](../rpcore/README.md).

## What the required mod does

The patch completes the client side of RPCore's EventCore-fed HUD data path. EventCore state reaches RPCore; RPCore's client code forwards bar data and configuration through Open77's `rtti.native` bridge; the redscript patch exposes the game-side endpoints and hands that data to Cyberpunk's native HUD controller/`inkWidget` system. The goal is to get dynamic RPCore data into the client's native HUD path, rather than render those bars in a WebView.

The patch is a client bridge/presentation integration. It does not run EventCore, decide when RP events happen, or implement the planned damage/netrunning/task outcome logic. Those event triggers remain EventCore/provider work.

## Install through the server's required-mod flow

Players do not install this source directory by copying it into the game manually. The Open77 resource preloads `rpcore/dist/rpcore-hud.zip`; the server advertises it as a required mod, and the OPEN//77 launcher installs it before the game starts.

Server operators should:

1. Enable `requiredMods` in the server configuration.
2. Use the exact client package intended for that server. If you modify or rebuild it, create a new archive and calculate its SHA-256 (from the bundle root in PowerShell: `Get-FileHash .\rpcore\dist\rpcore-hud.zip -Algorithm SHA256`; from inside `rpcore/`: `Get-FileHash .\dist\rpcore-hud.zip -Algorithm SHA256`). Update the matching `.sha256` file to that digest. Never reuse the published digest for different bytes.
3. Give that exact archive and its source/revision details to a compatible Open77/Warden server operator or review agent. Have them import their copy in Warden → Mods and request review/trust for its new SHA-256. Warden's trust decision applies to the exact bytes reviewed; every changed build has a different digest and needs a new review. An operator may instead use the platform's unsecured required-mod option only if they intentionally accept that policy.
4. Review/approve the exact SHA-256 of the deployed `rpcore/dist/rpcore-hud.zip`, recorded in `rpcore/dist/rpcore-hud.zip.sha256` and in the `rpcore-hud.zip.sha256` file beside this source.
5. Approve RPCore's `rtti.native` permission in Warden. Without it, RPCore can load but the native HUD bridge cannot pass data to the game-side patch.
6. Rebuild and request a new Warden hash review whenever the redscript package changes.

`requiredMods.unsecured: true` is an alternate server policy, not a requirement to copy this source folder to clients. Use the reviewed hash flow when the server requires a reviewed package.

### Project use terms

- <u>**You must own a valid copy of Cyberpunk 2077 and Phantom Liberty to download and use these modifications.**</u> Follow the current game, REDmod, and platform terms as well.
- This project is provided for **research and development purposes only**. Modification is encouraged. Do not sell or publicly repost/redistribute this code or package. The only permitted delivery exception under this project notice is the required-mod transfer to players connected to the operator's own server, as needed for the server to function.
- A Warden hash review is a technical trust/bytes review, not a copyright license, legal finding, or transfer of copyright responsibility. Operators remain responsible for what they submit, host, and deliver, including confirming they have the rights and permissions needed for their use.

See CD PROJEKT RED's [REDmod EULA](https://cdn-l-cyberpunk.cdprojektred.com/redmod_eula_en.pdf) and [Fan Content Guidelines](https://www.cdprojektred.com/en/fan-content). These project terms do not override those terms or grant rights to third-party material.

## Source files and build

The six `.reds` files under `r6/scripts/RPCore/` contain configuration, event/data ingress, HUD state storage, widget/controller integration, and diagnostic helpers. The matching deployment archive is `rpcore/dist/rpcore-hud.zip`.

From `rpcore/`, run `python3 tools/build-client-pack.py` to rebuild the deployment archive and checksum from `rpcore/redscript/r6/`. The extracted `rpcore-hud/` folder is preserved here for review; keep it synchronized with the resource's source and deployed archive.

See [`rpcore/docs/NATIVE-HUD.md`](../rpcore/docs/NATIVE-HUD.md) for transport details, current visual limitations, and diagnostics.
