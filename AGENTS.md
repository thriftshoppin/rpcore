# RPCore contributor handoff

## Current local work

- RPCore 0.3.2 makes `/rpcore.map` and the rebindable X action open the native City Map, selecting RPCore's Locations tab when available. Controller B opens the map while it is closed; the native map owns its B/back behavior after it opens.
- The previous bug was that adding a native map tab did not itself open the native map. `rpcore/client/map.lua` now owns the open request, handles Open77's map lifecycle events, and only closes a native session RPCore opened.
- Open77 exposes native map tabs and pins, but no supported API to relocate the minimap into a custom lower-left HUD panel. Do not fake an extracted map texture.
- See `CHANGELOG.md`, `rpcore/README.md`, and `CHECKPOINT.md` for the user-facing behavior and remaining in-game checks.

## Handoff and release

- Repository: `thriftshoppin/rpcore`; installable resource is in `rpcore/`.
- Test server resource lives under `C:\Users\Open77\Downloads\open77-server-2.31.21+op77.131-win-x64\resources\rpcore`.
- This work is prepared locally and needs in-game verification of `/rpcore.map`, X, controller B, native map tab selection, saved locations, and map permissions.
- Do not commit, push, or deploy until the user explicitly says “okay” for the pending changes. The user wants testing before GitHub publication and deploys only after local commits.
- Do not add a license before publication. The user reserves the right to choose release licensing later.
