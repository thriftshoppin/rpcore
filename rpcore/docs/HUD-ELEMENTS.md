# Controlling HUD elements (EventCore and other providers)

RPCore keeps a registry of every HUD element it can show, hide, fade, or move
(`shared/elements.lua`). A trusted resource — EventCore by default — drives those
elements per player through RPCore's server exports. RPCore validates every
request, owns the state, and publishes it to the player over EventCore's
versioned client-state feed (`rpcore.hud.control`). Clients only render it.

## Elements

| Id | Kind | visible | opacity | placement | Notes |
| --- | --- | :-: | :-: | :-: | --- |
| `vanilla.health` | native | ✓ | | | Game widget via `Open77.hud`. Untouched by default (`Config.vanilla` default `nil`); `vital.health` mirrors it. |
| `vanilla.stamina` | native | ✓ | | | Untouched by default. |
| `vanilla.weapon` | native | ✓ | | | Untouched by default. |
| `vanilla.minimap` | native | ✓ | | | Untouched by default (the player's own setting decides). |
| `vitals` | panel | ✓ | ✓ | ✓ | Character rail and all gauges. |
| `occupation` | panel | ✓ | ✓ | ✓ | |
| `weapon` | panel | ✓ | ✓ | ✓ | Weapon/ammo card. |
| `stack` / `journal` / `controls` | panel | ✓ | ✓ | ✓ | Activity cards, journal, controls panel. |
| `vital.health` `.stamina` `.armor` `.breath` `.food` `.water` `.sanity` | gauge | ✓ | ✓ | | `vital.sanity` is the cyberpsychosis meter. |
| `level` | gauge | ✓ | ✓ | | Level badge. |

`GetHudElements()` returns this catalog at runtime, including which operations
each element supports.

## Exports

Writes are refused unless the caller is in `Config.exports.allowedCallers`
(`"eventcore"` is allowed by default). Reads are open. All return
`true` or `nil, reason`.

```lua
-- patch = any of: visible (boolean), opacity (0..1), placement ({ x, y, scale })
-- placement x/y are 0..1 of the screen (top-left corner); scale is clamped to 0.35..1.
Open77.exports.call("rpcore", "SetHudElement", playerId, "vanilla.minimap", { visible = false }):await()
Open77.exports.call("rpcore", "SetHudElement", playerId, "vitals",
    { placement = { x = 0.62, y = 0.70, scale = 0.6 }, opacity = 0.8 }):await()
Open77.exports.call("rpcore", "ResetHudElement",  playerId, "vitals"):await()   -- one element
Open77.exports.call("rpcore", "ResetHudElements", playerId):await()             -- everything

Open77.exports.call("rpcore", "GetHudElements"):await()          -- catalog
Open77.exports.call("rpcore", "GetHudElementState", playerId):await()
```

Patches **merge**: setting `opacity` after `visible` keeps both. Reset removes an
element's override entirely. Refusal reasons: `caller_denied`, `unknown_element`,
`invalid_player_id`, `empty_patch`, `invalid_visible`, `invalid_opacity`,
`invalid_placement`, and `visible_unsupported` / `opacity_unsupported` /
`placement_unsupported` when the element cannot do that (for example placement on
a native widget).

Overrides live in server memory. The provider that owns them re-sends after an
RPCore or EventCore restart, exactly like survival vitals. A player's disconnect
clears their overrides.

## How this interacts with the player's own layout (F9)

Players keep arranging panels with the existing editor. A server **placement
override wins while it is set**; clearing it hands the element back to the
player's saved position, which was never overwritten. An element with a placement
override is locked in the editor (it cannot be dragged or resized) so the player
isn't fighting the server. Visibility and opacity overrides don't lock anything.

> **Superseded.** `SetBlackwall`, `SetRelicMalfunction` and `GetCyberpsychosisFx` now return
> `deprecated_use_ForceTier`. Effects follow the cyberpsychosis tier: drive them with `SetPsychosis` /
> `ForceTier` / `ReleaseTier` (see `docs/NATIVE-HUD.md`). The section below describes the retired API.
>
> From EventCore, use its `Hud*` exports (`EventCore docs/rpcore-integration.md`); EventCore is the
> resource RPCore allows to write HUD state.

## Blackwall and relic malfunction handles (retired)

The cyberpsychosis meter's **value** is unchanged: it is `sanity` from
`SetSurvivalVitals` (see `survival-vitals.md`). Two independent 0..1 effect levels
dress the meter and are driven by their own handles:

```lua
Open77.exports.call("rpcore", "SetBlackwall",        playerId, 0.7):await()  -- red/black interference deepens
Open77.exports.call("rpcore", "SetRelicMalfunction", playerId, 0.4):await()  -- panel glitches and flickers
Open77.exports.call("rpcore", "ClearCyberpsychosisFx", playerId):await()
Open77.exports.call("rpcore", "GetCyberpsychosisFx",   playerId):await()     -- { blackwall, relic }
```

Above a small threshold a status tag appears over the vitals
(`BLACKWALL INTERFERENCE`, `RELIC MALFUNCTION`, or both as `... · BLACKWALL BREACH`).
Levels are clamped to 0..1, are guarded by `allowedCallers`, and are cleared on
disconnect. Rules that decide *when* these levels change belong to the provider;
RPCore only renders them.

## Native widgets: what is and isn't possible

Open77 exposes **visibility** of native widgets (`Open77.hud`), not their
position. RPCore therefore gives native elements `visible` only; a request for
`placement` or `opacity` on `vanilla.*` is refused with `*_unsupported` instead of
being silently ignored. Where RPCore replaces a native widget it provides a
placeable mirror: `vanilla.weapon` ↔ the `weapon` card, and `vanilla.health` /
`vanilla.stamina` ↔ the gauges inside the `vitals` panel. Placement for the
gauges is per panel (`vitals`), not per gauge.

Moving the *actual* native minimap or any other native widget needs a native
(RED4ext) plugin that hooks the game's widget controller **and** a supported way
for Open77 to load it and call it from Lua. Neither exists in this repository,
and no plugin is included. If you add one, flip `supports.placement` for that
element in `shared/elements.lua` and handle it in `client/vanilla.lua`
(`setNative`); the validation, export, and feed plumbing already carry it.

## Adding other native components

Only `health`, `stamina`, `weapon`, and `minimap` are known to this codebase.
To manage another native component, check what your Open77 build says about it,
then add it to `Config.vanilla.extra`:

```
/rpcore.vanilla.probe crosshair ammo        -- prints the raw Open77.hud.isVisible result
/rpcore.vanilla                              -- lists claims and active overrides
```

```lua
vanilla = { extra = { { component = "ammo", label = "Native ammo", default = nil } } }
```

It then appears in the catalog as `vanilla.ammo` with visibility control.
