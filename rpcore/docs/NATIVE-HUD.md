# Native HUD: hunger, thirst and cyberpsychosis

The base Cyberpunk 2077 HUD stays as the game draws it (health, armor, stamina, weapon,
minimap, crosshair). RPCore adds three bars next to the vanilla health bar, drawn by the
game's own HUD controller. No WebUI is involved. Open77 is only the host.

```
provider/mission ──> EventCore ──> RPCore server ──> rpcore.hud snapshot ──> RPCore client Lua
 (SetVital …)        (handles)     vitals.lua         (EventCore feed)        client/native_hud.lua
                                                                                   │ Open77.rtti.call
                                                                                   ▼
                                       redscript pack (r6/scripts/RPCore) wraps healthbarWidgetGameController
```

## Install (server-required client mod)

RPCore ships its redscript pack as a **required client mod**. The `rpcore` resource declares
`preload_mod "dist/rpcore-hud.zip"`; the server stages and hosts it, announces it in the required-mod
set (Warden -> Mods lists it as `rpcore-assets`, with a `resource rpcore` badge), and the OPEN//77
launcher installs it into the world profile when a player presses Connect, before the game boots. No
manual copying, no restart on a normal join. Full operator steps: `SERVER-SETUP.md`.

**It is executable content** (`.reds`), so the platform's trust rules apply: the server must run
`requiredMods.unsecured: true` (players see an UNSECURED badge and a confirmation), or the pack's exact
SHA-256 must be verified through Warden's review. Each rebuild is a new hash and needs a new review.
Source of truth is `redscript/r6/scripts/RPCore/`; rebuild the zip with `python3 tools/build-client-pack.py`.

## Permission: rtti.native

`rtti.native` is the documented permission for `Open77.rtti` (open2077.net/docs/rtti). It was **missing**
from RPCore's manifest before this change (0.3.2 and the deployed 0.3.5); 0.4.0 declares it. It is a
privileged client API, so approve it for `rpcore` in Warden. Without it RPCore still loads; the bars do not
appear and `/rpcore.hud.native` reports `permission_denied`. States: `ready`, `permission_denied`,
`unavailable` (no `Open77.rtti` on this client build), `pack_missing` (client joined without the launcher /
pack, `function_not_found`), `failed`, `disabled`. The base HUD is untouched in every case. The bridge uses
the documented shape: `rtti.resolve(nil, name)` then `rtti.call(nil, decorated, nil, ...)` with every
parameter supplied.

## Operator tunables (Warden -> Tuning)

Declared in `Config.tunables`, all `live`, bounds enforced on every write, persisted by the host
(`tunables.json`). They ride inside every snapshot (`vitals.cfg`) so a change reaches players within ~1 s.

| Group | Tunable | Default | Range |
| --- | --- | --- | --- |
| Native HUD | `nativeBarsEnabled` | on | master switch: hides all bars and drops effects |
| Native HUD | `showBarsWithoutData` | off | show a bar before a provider sets it |
| Cyberpsychosis tiers | `strainedFrom` / `frayingFrom` / `breachFrom` / `psychosisFrom` | 25 / 50 / 75 / 90 | integers; must ascend, else defaults are used and a warning is logged |
| Cyberpsychosis tiers | `hysteresis` | 2 | 0-10 points |
| Relic malfunction | `relicEnabled` | on | |
| Relic malfunction | `relicRecord` | JohnnySicknessHeavy | enum of the four vanilla records (not free text) |
| Overrides | `overrideDefaultSeconds` / `overrideMaxSeconds` | 120 / 900 | 5-3600 / 30-3600 |

Tier labels, `blackwallEffectName`, bar labels and the web fallback flags stay in `Config` (file edit).

## Bars

| Bar | Direction | Look | Toggle |
| --- | --- | --- | --- |
| Hunger | drains toward empty | amber fill | `/rpcore.hunger [on\|off\|toggle]`, saved on the client |
| Thirst | drains toward empty | cyan fill | `/rpcore.thirst [on\|off\|toggle]`, saved on the client |
| Cyberpsychosis (`psychosis`) | **fills** as risk rises | red fill + 4 tier ticks, label `CYBERPSYCHOSIS / <TIER>` | none |

Hunger and thirst are on by default. A server force-hide (`SetBarVisible`) beats the player's
toggle. A bar with no provider value stays hidden (RPCore invents no numbers;
`Config.vitals.showWithoutData` changes that). RPCore does not simulate drain.

`sanity` is a **deprecated alias** of `psychosis` in `SetVital`, `SetBarVisible` and
`SetSurvivalVitals`: same 0-100 direction, never inverted, logs one warning.

## Tiers and effects

Bounds are the tier tunables above (ids are fixed, labels live in `Config.psychosis.tiers`). Falling needs
`hysteresis` points below a bound.

| Tier | Range | Effect |
| --- | --- | --- |
| Stable | 0-25 | none |
| Strained | 25-50 | red tint + light flicker on the bar |
| Fraying | 50-75 | `inkBlackwallEffect` on the vitals bars (0.45) |
| Breach | 75-90 | heavier `inkBlackwallEffect` on the bars, the vanilla health bar and 2 ancestors (0.8) |
| Psychosis | 90-100 | Breach look at 1.0 + the game's relic malfunction (`BaseStatusEffect.JohnnySicknessHeavy`) |

### Blackwall effect: read this
`inkWidget` offers `SetEffectEnabled` / `SetEffectParamValue` (confirmed in the 2.31 RTTI manifest)
but **no way to create an effect at runtime**. The effect must already be on the widget, authored in
an `.inkwidget`. Bars built from script have none. The pack still calls the real API, and reads the
parameter back: `blackwall=present|absent` in `/rpcore.hud.native`. Expect `absent` until either
(a) the bars are spawned from a WolvenKit-authored `.inkwidget` carrying an `inkBlackwallEffect` named
`Config.psychosis.blackwallEffectName`, or (b) you tell me which vanilla widget/effect name to target
(this is what the missing WolvenKit exports would have answered). Strained tint/flicker, ticks and the relic
effect do not depend on this. If GlitchBegone (or similar) is installed it removes the fullscreen glitch assets.

### Relic malfunction and Open77
Open77MultiplayerPolicy.reds, while a session is active: removes the four `JohnnySickness*` records
the moment they apply (`PlayerPuppet.OnStatusEffectApplied`), skips `johnny_sickness*` VFX/SFX
(`GameObject.StartStatusEffectVFX/SFX`) and hides the Relic warning banner
(`WarningMessageGameController.OnWarningMessageUpdate`). RPCore detects this **by behaviour** (applied, gone
~0.5 s later), sets `relic=suppressed`, keeps Blackwall-only escalation, tries again once per entry into Psychosis,
and Lua prints one chat line. No Open77 file is edited. To allow the effect Open77 would need a narrow exemption in
those three wrappers (policy-active guard skipped for effects RPCore applies, e.g. a flag/claim set by RPCore through a
new Open77 API; the first wrapper must keep the removal for every other source). That is Open77's call.
Also unverified: whether the vanilla Johnny-sickness records carry gameplay penalties (movement, camera); read the TweakDB records first.

## Overrides

Precedence: **ForceTier > SetPsychosis with ttl > provider baseline (automatic tier)**. Every override expires
(tunables `overrideDefaultSeconds` / `overrideMaxSeconds`: 120 s / 900 s by default; refresh long effects). Expiry is enforced three times: the
server (1 s sampler), the client (local deadline from the snapshot's remaining ms), and the game side (no push
or heartbeat for ~15 s drops every effect to Stable). A forced tier shows the bar clamped inside that tier.

## Handles (RPCore server exports)

Writes are refused unless the caller is in `Config.exports.allowedCallers` (default `eventcore`). All return
`true` or `nil, reason`. Examples use `Open77.exports.call("rpcore", name, ...):await()`.

| Handle | Arguments | Notes |
| --- | --- | --- |
| `SetVital` | `player, vital, value, max?` | vital: `hunger`, `thirst`, `psychosis` (`sanity` deprecated alias). Clamped to `0..max`. |
| `SetPsychosis` | `player, value, opts?` | no ttl = provider baseline. `opts = { max?, ttl?, source? }` or a ttl number = timed level override. |
| `ForceTier` | `player, tier, ttl?, source?` | tier: `stable strained fraying breach psychosis` or 1-5. Missing ttl = default; capped. |
| `ReleaseTier` | `player, which?` | `all` (default), `tier`, `level`. |
| `SetBarVisible` | `player, bar, visible, ttl?, source?` | `false` = force-hide until ttl (beats the player's toggle). `true`/`nil` = release the force-hide. |
| `GetVitals` / `GetPsychosisTiers` | `player` / – | open reads. |

Reasons: `caller_denied`, `exports_disabled`, `invalid_player_id`, `unknown_vital`, `unknown_bar`, `unknown_tier`,
`invalid_value`, `invalid_max`, `invalid_ttl`, `invalid_source` (`^[%w_%-%.:/ ]{1,64}$`), `invalid_visible`,
`invalid_release`, `invalid_options`.

```lua
Open77.exports.call("rpcore", "SetVital", player, "hunger", 74):await()
Open77.exports.call("rpcore", "SetPsychosis", player, 62):await()                       -- baseline
Open77.exports.call("rpcore", "ForceTier", player, "breach", 60, "mission:q101"):await()  -- pin for 60 s
Open77.exports.call("rpcore", "ReleaseTier", player):await()
Open77.exports.call("rpcore", "SetBarVisible", player, "thirst", false, 30, "cutscene"):await()
```

Legacy: `SetSurvivalVitals` / `ClearSurvivalVitals` still work (now guarded by `allowedCallers`; they were open).
`SetBlackwall` / `SetRelicMalfunction` / `GetCyberpsychosisFx` now return `nil, "deprecated_use_ForceTier"`.
`ClearCyberpsychosisFx` = `ReleaseTier(all)`.

## What Open77 still hides online (left as is)

From Open77MultiplayerPolicy.reds (unconditional while a session is active):
- Input hints (`input_hint` entry and `InputHintManagerGameController`).
- Phone / quick-slot / hotkey cluster (`gameuiNewPhoneRelatedHUDGameController`: `HotkeysWidgetController`,
  `HotkeyConsumableWidgetController`), plus the phone controller and its messages.
- Stance silhouette (`CrouchIndicatorGameController`, red body icon, lower right).
- Relic warning banner (see above) and Johnny-sickness VFX/SFX.
Also claim-driven (hidden only if a resource claims them through `Open77.hud`): minimap, compass, clock, health,
stamina, weapon, speedometer, quest tracker, scanner, notifications, crosshair, hub menu. Third-person mode hides
the native HUD (including these bars) per `CHECKPOINT.md`.

## Risks (none exercised in game)

- **rtti transport**: the call shape and permission now follow the published docs, but nothing has run in
  game. The docs say `rtti.call` reaches scripted functions through the SDK's script-stack path; Open77's own
  ScriptBridge comments warn that native code running scripted logic without a script frame terminates the
  process. Whether that applies to this path is unknown, so the receivers only store values (widgets are touched
  later from the controller's own tick). Run `/rpcore.hud.native.ping` on a test client first; the platform's
  `open77_rtti_test` resource and `rtti.state` debug command show whether the bridge itself is healthy.
- `GetGameInstance()` inside the receivers: Open77 measured it failing inside a delay callback. If unreachable, ping
  returns false and Lua reports it.
- A redscript compile error shows a dialog at boot for every player who joins (the launcher installs the pack
  before the game starts), so test the pack on one client first. Unproven redscript calls (not used by Open77, so not compile-proven): `StatusEffectHelper.ApplyStatusEffect`,
  `StringToName`, `StrUpper`, `inkText.SetFontFamily(path, style)`, `inkAnimTransparency.SetType/SetMode`,
  `inkWidget.SetEffect*`. A compile error in any redscript file blocks script loading: install on a test client first.
- Layout is a heuristic (same anchor as the vanilla bar, stacked past it). Style is approximate (no exports supplied).

## Switching to Solo (reverting the game files)

The pack only **adds** new files (`r6/scripts/RPCore/RPCoreHudSystem.reds`, `RPCoreHudBars.reds`); it replaces
nothing the game or Open77 ships, so removal is clean. Per the platform docs the launcher keeps the pack in a
per-world profile, separate from the player's own game:
- Pressing **Solo** in the launcher's mod menu projects the player's own mod set and takes the world layer out:
  both `.reds` files are removed from `r6/scripts/RPCore/`, so the game compiles without them. World files never
  appear in Solo.
- The mod menu's **Worlds** section lists these files under the world that required them, with a "remove this
  world's mods" action. Joining another world swaps world files; leaving the server never needs a manual uninstall.
- Cached bytes stay in the launcher's store until the player frees the space.
- Nothing from RPCore lingers in the game: the pack keeps no files outside `r6/scripts/RPCore/` and the vanilla
  health bar is never modified. If the game is somehow started with the pack but no RPCore feed, the bars stay
  hidden and no effect runs (nothing is pushed, nothing is applied at Stable).
Prove the round trip once on a test client (join, then Solo, then check the folder is gone) before relying on it.
