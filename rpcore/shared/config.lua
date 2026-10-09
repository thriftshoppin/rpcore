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
        map = "X",              -- open native City Map and select RPCore Locations
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
        allowedCallers = {},     -- e.g. { "my_fixer_module" }
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
