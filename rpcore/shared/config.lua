--- RPCore configuration. Everything tunable lives here; no magic values elsewhere.
-- This file belongs to the SERVER that installs RPCore. Engine code never reads
-- a server-specific value from anywhere else.
RPCore = RPCore or {}

RPCore.Config = {
    debug = false,              -- developer diagnostics in the server log (never in the player UI)

    -- Player-facing presentation (sent to the page once at start).
    ui = {
        anchor = "top-right",   -- top-left | top-right | bottom-left | bottom-right
        offsetX = 24,           -- px from that screen edge
        offsetY = 168,          -- px from that screen edge (clears a top-right status panel; tune per server)
        scale = 1.0,            -- 0.75 .. 1.5
        accent = "#4ade80",     -- accent colour; the page derives its tints from it
        brand = "RPCORE",       -- small label on every card (a server may rebrand it)
        offerWidth = 330,
        trackerWidth = 290,
        resultMs = 7000,         -- how long the completion / failure card stays up
        objectiveCheckMs = 1300, -- how long a finished objective shows its check before the next one
        notificationMs = 6000,   -- toast duration for short notices (declined, lapsed, ...)
    },

    -- Default keys. These are DEFAULTS: players can rebind them in the pause menu.
    -- Low-collision test defaults. Every action can be changed from the F6
    -- RPCore Controls panel or Open77 Pause -> Settings -> Key Bindings.
    keys = {
        settings = "F6",
        accept = "F7",
        decline = "F11",
        action = "F12",
        journal = "INSERT",
        hudToggle = "HOME",
        layout = "F9",
        map = "M",              -- open the native City Map and select RPCore Locations
    },

    -- Native (vanilla) Cyberpunk HUD components RPCore can show/hide through Open77's
    -- `Open77.hud` API (needs the `ui.vanilla.hud` permission). Each entry becomes
    -- the controllable element "vanilla.<component>".
    --   default : visibility RPCore asks for at start. EVERY DEFAULT IS nil: the base
    --             game's own HUD (health, armor, stamina, weapon, minimap, crosshair)
    --             stays exactly as the game draws it. RPCore adds bars next to them;
    --             it does not replace or hide them. A server may still hide one at
    --             runtime through SetHudElement.
    --   mirror  : only meaningful for the optional web fallback (webFallback below).
    -- Only `health`, `stamina`, `weapon` and `minimap` are known to this codebase.
    -- Add other component names to `extra` ONLY after `/rpcore.vanilla.probe <name>`
    -- says your Open77 build accepts them.
    vanilla = {
        native = {
            { component = "health",  label = "Native health",  default = nil, mirror = "vital.health" },
            { component = "stamina", label = "Native stamina", default = nil, mirror = "vital.stamina" },
            { component = "weapon",  label = "Native weapon",  default = nil, mirror = "weapon" },
            { component = "minimap", label = "Native minimap", default = nil },
        },
        extra = {},              -- e.g. { { component = "ammo", label = "Native ammo", default = nil } }
    },

    -- RPCore's old WebUI (CEF) HUD surfaces. ALL OFF: the base game HUD is the HUD and the
    -- hunger / thirst / cyberpsychosis bars are drawn natively by the redscript pack
    -- (redscript/r6/scripts/RPCore). Turn one on only as a fallback while the native
    -- pack is not installed. Switching one on duplicates the matching base-game widget
    -- (weapon card, crosshair) -- that is why they are off.
    webFallback = {
        vitals = false,          -- web/hud/index.html: vitals panel + occupation + gauges. OFF: the base game HUD is the HUD
                                 -- and its food/water/sanity rows would duplicate the native bars. Set true only as a
                                 -- fallback while the native redscript pack is not installed.
        weapon = false,          -- web/hud/weapon.html: weapon card (duplicates the native weapon widget)
        crosshair = false,       -- web/hud/crosshair.html: third-person crosshair
    },

    -- Native vitals bars: hunger, thirst, cyberpsychosis (see docs/NATIVE-HUD.md).
    vitals = {
        hunger = { label = "HUNGER", max = 100 },
        thirst = { label = "THIRST", max = 100 },
        -- RPCore simulates nothing: a bar with no provider value stays hidden instead of
        -- showing an invented number. Set true to show an empty bar until a value arrives.
        showWithoutData = false,
    },

    -- Cyberpsychosis meter: a 0-100 danger meter that FILLS as risk rises. Tier BOUNDS, hysteresis,
    -- the relic effect and override lifetimes are operator tunables (below). Ids are fixed (effects
    -- are keyed on them); `label` is yours. `from` here is documentation of the defaults only.
    psychosis = {
        label = "CYBERPSYCHOSIS",
        max = 100,
        tiers = {
            { id = "stable",    label = "Stable",    from = 0  },   --  0-25
            { id = "strained",  label = "Strained",  from = 25 },   -- 25-50  tint + light flicker on the bar
            { id = "fraying",   label = "Fraying",   from = 50 },   -- 50-75  inkBlackwallEffect on the vitals bars
            { id = "breach",    label = "Breach",    from = 75 },   -- 75-90  heavier inkBlackwallEffect across the HUD
            { id = "psychosis", label = "Psychosis", from = 90 },   -- 90-100 + the game's relic malfunction
        },
        -- Name of the Blackwall effect on the widgets the redscript pack drives. The effect has to
        -- exist on the widget (authored in the .inkwidget); see docs/NATIVE-HUD.md.
        blackwallEffectName = "blackwall",
    },

    -- Operator tunables: what a server owner retunes LIVE from Warden's Tuning tab (no Lua edit,
    -- no restart). This table is DATA (it is downloaded to clients, so keep the prose publishable);
    -- the `Open77.tunables.declare` call lives in server/vitals.lua. Bounds are enforced on every
    -- write. Tier bounds are checked together (ascending) when read: an inconsistent set is refused
    -- and the defaults are used until it is fixed (a warning is logged).
    -- Without Open77.tunables (older host, tests) the `value` below is used as-is.
    tunables = {
        nativeBarsEnabled = { value = true, type = "boolean", apply = "live", group = "Native HUD", order = 1,
            label = "Show the hunger / thirst / cyberpsychosis bars",
            description = "Master switch for the bars drawn on the game's own HUD. Off hides them and drops every effect on all players." },
        showBarsWithoutData = { value = false, type = "boolean", apply = "live", group = "Native HUD", order = 2,
            label = "Show a bar before any value is pushed",
            description = "Off: a bar stays hidden until a provider sets its value, so no invented number is shown." },
        strainedFrom = { value = 25, type = "integer", min = 1, max = 98, step = 1, apply = "live", group = "Cyberpsychosis tiers", order = 1,
            label = "Strained starts at", description = "Meter value where the tint and flicker begin. Must stay below the next three." },
        frayingFrom = { value = 50, type = "integer", min = 2, max = 98, step = 1, apply = "live", group = "Cyberpsychosis tiers", order = 2,
            label = "Fraying starts at", description = "Blackwall glitch on the vitals bars begins here." },
        breachFrom = { value = 75, type = "integer", min = 3, max = 99, step = 1, apply = "live", group = "Cyberpsychosis tiers", order = 3,
            label = "Breach starts at", description = "Heavier Blackwall glitch across the HUD begins here." },
        psychosisFrom = { value = 90, type = "integer", min = 4, max = 99, step = 1, apply = "live", group = "Cyberpsychosis tiers", order = 4,
            label = "Psychosis starts at", description = "Relic malfunction (when allowed) begins here." },
        hysteresis = { value = 2, type = "number", min = 0, max = 10, step = 0.5, unit = "pts", apply = "live", group = "Cyberpsychosis tiers", order = 5,
            label = "Tier hysteresis", description = "Points a falling value must drop below a tier's start before the tier drops. Stops flicker on a boundary." },
        relicEnabled = { value = true, type = "boolean", apply = "live", group = "Relic malfunction", order = 1,
            label = "Apply the relic malfunction at Psychosis",
            description = "Uses the game's own Johnny-sickness effect. If the platform's multiplayer policy strips it, the HUD falls back to Blackwall-only and says so." },
        relicRecord = { value = "BaseStatusEffect.JohnnySicknessHeavy", type = "enum", apply = "live", group = "Relic malfunction", order = 2,
            choices = { "BaseStatusEffect.JohnnySicknessLow", "BaseStatusEffect.JohnnySicknessMedium",
                        "BaseStatusEffect.JohnnySicknessHeavy", "BaseStatusEffect.JohnnySicknessMediumQuest" },
            label = "Relic effect strength", description = "Which vanilla Johnny-sickness effect is applied at Psychosis." },
        overrideDefaultSeconds = { value = 120, type = "integer", min = 5, max = 3600, unit = "s", apply = "live", group = "Overrides", order = 1,
            label = "Default override lifetime", description = "Used when a mission forces a tier or hides a bar without giving a lifetime." },
        overrideMaxSeconds = { value = 900, type = "integer", min = 30, max = 3600, unit = "s", apply = "live", group = "Overrides", order = 2,
            label = "Longest override lifetime", description = "No override outlives this, so a crashed mission cannot leave the HUD glitching. Long effects must be refreshed." },
    },

    -- Client -> game transport for the native bars (client/native_hud.lua).
    -- Requires the `rtti.native` permission in open77.lua AND that the server grants it (Warden).
    -- (The server-wide on/off switch is the `nativeBarsEnabled` tunable.)
    nativeHud = {
        enabled = true,          -- false = this client never touches Open77.rtti
        minGapMs = 150,          -- minimum gap between value pushes
        heartbeatMs = 2000,      -- resend state so the game side knows RPCore is alive
        statusPollMs = 5000,     -- how often to read the game-side status string
    },

    -- Net events a client may raise as a game event. Anything else is ignored.
    -- Real content should emit objective events from the server (RPCore.Events.Emit).
    clientEvents = { ["rpcore.action"] = true },

    limits = {
        netIntervalMs = 250,     -- minimum gap between two net events from one player
        historyPerPlayer = 25,   -- finished activities kept in memory per player
    },

    -- Rewards. `provider` says how a "currency" reward is paid; RPCore itself has
    -- no economy. type = "none" shows the reward but pays nothing.
    reward = {
        currencyFormat = "$%d",  -- how an amount is displayed
        provider = {
            -- Ships as "none" so RPCore installs with ZERO edits to any other resource.
            -- To pay real money: set type = "export", add "rpcore" to the economy resource's
            -- trusted caller allow-list, and set the
            -- demo reward below to { kind = "currency", amount = 500 }.
            type = "none",           -- "export" | "none" | (register your own: RPCore.Rewards.RegisterProvider)
            resource = "example_economy", -- SERVER-SPECIFIC: the resource exporting the call below
            export = "AddMoney",     -- called as export(player, currency, amount, reason)
            currency = "EDDIES",     -- second argument of the call
            reason = "rpcore",       -- fourth argument (audit label)
        },
    },

    -- Public exports (server/exports.lua). Writes are refused unless the calling
    -- resource is listed here. Empty = none.
    exports = {
        enabled = true,
        -- "eventcore" may drive HUD elements and the Blackwall / relic handles
        -- (SetHudElement, SetBlackwall, ...). Add other trusted resources here.
        allowedCallers = { "eventcore" },     -- e.g. { "eventcore", "my_fixer_module" }
    },

    -- The built-in demonstration activity (server/demo.lua).
    demo = {
        enabled = true,
        command = "rpcore.demo",     -- restricted: needs the ACL right command.rpcore.demo
        offerTimeoutMs = 60000,
        standbyMs = 8000,            -- objective 2 resolves after this long
        reward = { kind = "display", label = "Field Test commendation" },  -- display-only, pays nothing
    },
}
