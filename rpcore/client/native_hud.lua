-- RPCore native HUD bridge (client).
--
-- Hands PLAIN VALUES (floats, strings, bools) to the redscript pack in
-- redscript/r6/scripts/RPCore, which draws the hunger / thirst / cyberpsychosis bars
-- on the game's own HUD (it wraps healthbarWidgetGameController). Nothing here draws
-- anything: no WebUI, no Open77 HUD API as a visual source.
--
-- Transport: Open77.rtti (https://open2077.net/docs/rtti): `rtti.resolve(class, fn)` and
-- `rtti.call(class, fn, instance, ...)` -> value | nil, reason. Globals use class = nil and
-- instance = nil; every declared parameter must be supplied. Needs the `rtti.native`
-- permission (open77.lua), which the server must approve in Warden. Every failure is
-- reported (not swallowed) and leaves the base game HUD untouched.
--
-- Game-side functions this file calls (all defined in RPCoreHudSystem.reds):
--   RPCoreHudPing() -> Bool
--   RPCoreHudConfigure(bounds: String, labels: String, relicEnabled: Bool, relicRecord: String,
--                      fxName: String, psychosisLabel: String, hungerLabel: String, thirstLabel: String) -> Bool
--   RPCoreHudSetBar(bar: String, visible: Bool, value: Float, max: Float) -> Bool        bar = hunger | thirst
--   RPCoreHudSetPsychosis(visible: Bool, value: Float, max: Float, tier: Int32) -> Bool  tier 1..5
--   RPCoreHudHeartbeat() -> Bool
--   RPCoreHudClear() -> Bool
--   RPCoreHudStatus() -> String                      "k=v;k=v" (relic, blackwall, attached, ...)
RPCore = RPCore or {}
RPCore.NativeHud = RPCore.NativeHud or {}

local NativeHud = RPCore.NativeHud
local Config = RPCore.Config
local V = RPCore.Vitals
local cfg = type(Config.nativeHud) == "table" and Config.nativeHud or {}

local PREFS_KEY = "rpcore:vitals:v1"
local STALE_SNAPSHOT_MS = 15000          -- no snapshot for this long: drop overrides locally
local RETRY_MS = { 5000, 10000, 30000 }  -- probe backoff after a generic failure

local tiers, tierProblem = V.BuildTiers(Config.psychosis)
if tierProblem then print("[rpcore] psychosis tier config refused, using defaults: " .. tierProblem) end

-- ── state ───────────────────────────────────────────────────────────────────

local prefs = { hunger = true, thirst = true }   -- player toggles, saved on this client
local transport = {
    state = "unprobed",   -- unprobed | disabled | unavailable | permission_denied | failed | ready
    reason = nil, calls = 0, failures = 0, probeFailures = 0, nextProbeAt = 0,
}
local gameStatus = { raw = "", fields = {}, lastRelic = nil }
local snapshot = nil          -- latest server `vitals` table
local snapshotAt = 0
local deadlines = {}          -- local expiry for overrides: forced / level / hidden[bar]
local hudShown = false
local pushed = {}             -- last value signature per channel
local lastPushAt, lastBeatAt, lastStatusAt = 0, 0, 0
local configured = false
local started = false

local function now() return GetGameTimer() end

local function say(text)
    print("[rpcore] " .. text)
    TriggerEvent("chat:addMessage", { type = "system", author = "RPCore", text = text })
end

-- ── prefs (per player, client side) ─────────────────────────────────────────

local function loadPrefs()
    local kvp, json = Open77 and Open77.kvp, Open77 and Open77.json
    if not (kvp and json and type(kvp.get) == "function" and type(json.decode) == "function") then return end
    local raw = kvp.get(PREFS_KEY)
    if type(raw) ~= "string" or raw == "" then return end
    local decoded = json.decode(raw)
    if type(decoded) ~= "table" then return end
    for name in pairs(V.TOGGLEABLE) do
        if type(decoded[name]) == "boolean" then prefs[name] = decoded[name] end
    end
end

local function savePrefs()
    local kvp, json = Open77 and Open77.kvp, Open77 and Open77.json
    if not (kvp and json and type(kvp.set) == "function" and type(json.encode) == "function") then return end
    local encoded = json.encode({ hunger = prefs.hunger, thirst = prefs.thirst })
    if type(encoded) == "string" then
        local ok, reason = kvp.set(PREFS_KEY, encoded)
        if not ok then print("[rpcore] could not save vitals preferences: " .. tostring(reason)) end
    end
end

-- ── transport ───────────────────────────────────────────────────────────────

local function rttiApi()
    local rtti = Open77 and Open77.rtti
    if type(rtti) == "table" and type(rtti.call) == "function" then return rtti end
    return nil
end

local resolved = {}   -- short name -> decorated name reported by RTTI

--- The ONE place that talks to Open77.rtti. Returns ok, value | reason.
-- A pcall error, a `nil, reason` result, or a receiver that answers `false` is a failure.
local function invoke(fn, ...)
    local rtti = rttiApi()
    if not rtti then return false, "open77_rtti_missing" end
    local name = resolved[fn]
    if not name then
        if type(rtti.resolve) == "function" then
            local okResolve, signature, why = pcall(rtti.resolve, nil, fn)
            if not okResolve then return false, tostring(signature) end
            if type(signature) ~= "table" then return false, tostring(why or "function_not_found") end
            name = signature.name or fn
        else
            name = fn
        end
        resolved[fn] = name
    end
    local ok, value, reason = pcall(rtti.call, nil, name, nil, ...)
    transport.calls = transport.calls + 1
    if not ok then return false, tostring(value) end
    if reason ~= nil then
        if tostring(reason):find("function_not_found", 1, true) then resolved[fn] = nil end
        return false, tostring(reason)
    end
    if value == nil then return false, "no_result" end
    if value == false then return false, "receiver_refused" end
    return true, value
end

local function classify(reason)
    reason = tostring(reason or ""):lower()
    if reason:find("permission", 1, true) or reason:find("denied", 1, true) or reason:find("not granted", 1, true) then
        return "permission_denied"
    end
    if reason == "open77_rtti_missing" or reason:find("rtti_unavailable", 1, true) then return "unavailable" end
    if reason:find("function_not_found", 1, true) then return "pack_missing" end
    return "failed"
end

local function setTransport(state, reason)
    if transport.state ~= state or transport.reason ~= reason then
        transport.state, transport.reason = state, reason
        if state == "ready" then
            print("[rpcore] native HUD transport ready")
        elseif state == "pack_missing" then
            say("native HUD bars unavailable: the RPCore client pack is not installed in this game. Join through the OPEN//77 launcher so the server's required mods are installed. The base game HUD is unchanged.")
        elseif state ~= "unprobed" and state ~= "disabled" then
            say(("native HUD bars unavailable (%s: %s). The base game HUD is unchanged. See /rpcore.hud.native."):format(state, tostring(reason)))
        end
    end
end

local function csv(list) return table.concat(list, ",") end

--- Operator-tunable presentation config arrives inside every snapshot (`vitals.cfg`).
local cfgSignature
local function cfgOf(vitals)
    local c = type(vitals) == "table" and vitals.cfg or nil
    return type(c) == "table" and c or nil
end

local function signatureOf(c)
    local bounds, labels = {}, {}
    for i, v in ipairs(c.bounds or {}) do bounds[i] = ("%.4f"):format(tonumber(v) or 0) end
    for i, v in ipairs(c.labels or {}) do labels[i] = (tostring(v):gsub("[,;=]", " ")) end
    return csv(bounds), csv(labels), tostring(c.relicEnabled == true) .. "|" .. tostring(c.relicRecord or "")
end

local function configure()
    local c = cfgOf(snapshot)
    if not c then return false, "no_server_config_yet" end
    local bounds, labels, rest = signatureOf(c)
    local ok, reason = invoke("RPCoreHudConfigure", bounds, labels, c.relicEnabled == true,
        tostring(c.relicRecord or ""), tostring(Config.psychosis.blackwallEffectName or ""),
        tostring(Config.psychosis.label or "CYBERPSYCHOSIS"),
        tostring(Config.vitals.hunger.label or "HUNGER"), tostring(Config.vitals.thirst.label or "THIRST"))
    configured = ok
    if ok then cfgSignature = bounds .. "#" .. labels .. "#" .. rest end
    return ok, reason
end

local function serverEnabled()
    local c = cfgOf(snapshot)
    return not c or c.enabled ~= false
end

--- Probe once: a harmless Ping, then Configure. Safe to call repeatedly.
local function probe(force)
    if cfg.enabled == false then setTransport("disabled", "Config.nativeHud.enabled = false") return false end
    local t = now()
    if not force and t < transport.nextProbeAt then return false end
    if not rttiApi() then
        setTransport("unavailable", "Open77.rtti is not exposed on this build")
        return false
    end
    local ok, a, b = invoke("RPCoreHudPing")
    if ok then
        local cfgOk, cfgReason = configure()
        if not cfgOk then
            transport.probeFailures = transport.probeFailures + 1
            transport.nextProbeAt = t + RETRY_MS[math.min(transport.probeFailures, #RETRY_MS)]
            setTransport("failed", "RPCoreHudConfigure: " .. tostring(cfgReason))
            return false
        end
        transport.probeFailures, transport.failures = 0, 0
        pushed = {}
        setTransport("ready", nil)
        return true
    end
    local state = classify(a)
    transport.probeFailures = transport.probeFailures + 1
    -- A missing permission or API will not fix itself; a missing game-side pack might
    -- (late HUD attach), so only that case keeps retrying.
    if state == "failed" then
        transport.nextProbeAt = t + RETRY_MS[math.min(transport.probeFailures, #RETRY_MS)]
    else
        transport.nextProbeAt = math.huge
    end
    setTransport(state, tostring(a))
    return false
end

local function transportFailure(reason)
    transport.failures = transport.failures + 1
    if transport.failures >= 3 then
        configured = false
        transport.state = "unprobed"       -- re-probe (and reconfigure) with backoff
        transport.nextProbeAt = now() + RETRY_MS[1]
        setTransport("failed", tostring(reason))
    end
end

-- ── effective values ────────────────────────────────────────────────────────

local function past(deadline) return deadline ~= nil and now() >= deadline end

local function effectivePsychosis()
    local p = snapshot and snapshot.psychosis
    if type(p) ~= "table" then return nil end
    local value, tier = tonumber(p.value) or 0, tonumber(p.tier) or 1
    if p.forced or p.level then
        -- Safety net: if snapshots stop arriving, an override must not outlive its ttl.
        local live = (p.forced and not past(deadlines.forced)) or (p.level and not past(deadlines.level))
        if not live then value, tier = tonumber(p.base) or 0, tonumber(p.autoTier) or 1 end
    end
    if not serverEnabled() then tier = 1 end      -- operator switched the bars off: no effects either
    return value, V.Clamp(math.floor(tier), 1, 5), tonumber(p.max) or 100
end

local function barVisible(name, bar)
    if type(bar) ~= "table" or not hudShown then return false end
    if bar.hidden and not past(deadlines.hidden and deadlines.hidden[name]) then return false end
    local c = cfgOf(snapshot)
    if not serverEnabled() then return false end
    if not (bar.hasData or (c and c.showWithoutData == true)) then return false end
    if V.TOGGLEABLE[name] and prefs[name] == false then return false end
    return true
end

-- ── pushing ─────────────────────────────────────────────────────────────────

local function push(force)
    if transport.state ~= "ready" or not snapshot then return end
    local t = now()
    if not force and t - lastPushAt < (tonumber(cfg.minGapMs) or 150) then return end

    local c = cfgOf(snapshot)
    if c then
        local b, l, r = signatureOf(c)
        if cfgSignature ~= b .. "#" .. l .. "#" .. r then
            local ok, reason = configure()
            if not ok then transportFailure(reason) return end
        end
    end

    local changed = false
    local function send(channel, signature, fn, ...)
        if not force and pushed[channel] == signature then return end
        local ok, reason = invoke(fn, ...)
        if ok then pushed[channel] = signature; changed = true else transportFailure(reason) end
    end

    for _, name in ipairs({ "hunger", "thirst" }) do
        local bar = snapshot[name]
        if type(bar) == "table" then
            local visible = barVisible(name, bar)
            local value, max = tonumber(bar.value) or 0, tonumber(bar.max) or 100
            send(name, ("%s|%.1f|%.1f"):format(tostring(visible), value, max), "RPCoreHudSetBar", name, visible, value + 0.0, max + 0.0)
        end
    end

    local value, tier, max = effectivePsychosis()
    if value then
        local visible = barVisible("psychosis", snapshot.psychosis)
        send("psychosis", ("%s|%.1f|%.1f|%d"):format(tostring(visible), value, max, tier),
            "RPCoreHudSetPsychosis", visible, value + 0.0, max + 0.0, math.tointeger(tier) or 1)
    end

    if changed then lastPushAt, lastBeatAt = t, t
    elseif t - lastBeatAt >= (tonumber(cfg.heartbeatMs) or 2000) then
        -- Nothing changed: still tell the game side RPCore is alive. It drops all effects
        -- when this stops (crashed resource / stalled feed), so nothing stays stuck on.
        local ok, reason = invoke("RPCoreHudHeartbeat")
        if ok then lastBeatAt = t else transportFailure(reason) end
    end
end

local function parseStatus(raw)
    local fields = {}
    for key, value in tostring(raw):gmatch("([%w_]+)=([^;]*)") do fields[key] = value end
    return fields
end

local function pollStatus()
    if transport.state ~= "ready" then return end
    local ok, a, b = invoke("RPCoreHudStatus")
    if not ok then transportFailure(a) return end
    local raw = type(a) == "string" and a or (type(b) == "string" and b or nil)
    if not raw then return end
    gameStatus.raw, gameStatus.fields = raw, parseStatus(raw)
    local relic = gameStatus.fields.relic
    if relic ~= gameStatus.lastRelic then
        gameStatus.lastRelic = relic
        if relic == "suppressed" then
            say("relic malfunction effect was SUPPRESSED (Open77's multiplayer policy strips the Johnny-sickness effects). Escalation continues with Blackwall effects only. See docs/NATIVE-HUD.md.")
        end
    end
end

-- ── feed from client/hud.lua ────────────────────────────────────────────────

--- Called by client/hud.lua's apply() on every state update, menu change and HUD toggle.
function NativeHud.OnState(state, shown)
    hudShown = shown == true
    local vitals = type(state) == "table" and state.vitals or nil
    if type(vitals) == "table" and vitals ~= snapshot then
        snapshot, snapshotAt = vitals, now()
        deadlines = { hidden = {} }
        local p = vitals.psychosis
        if type(p) == "table" then
            if p.forced and tonumber(p.forcedTtlMs) then deadlines.forced = snapshotAt + p.forcedTtlMs end
            if p.level and tonumber(p.levelTtlMs) then deadlines.level = snapshotAt + p.levelTtlMs end
        end
        for name, bar in pairs(vitals) do
            if type(bar) == "table" and bar.hidden and tonumber(bar.hiddenTtlMs) then
                deadlines.hidden[name] = snapshotAt + bar.hiddenTtlMs
            end
        end
    end
    push(false)
end

-- ── loop ────────────────────────────────────────────────────────────────────

local function tick()
    if cfg.enabled == false then return end
    if transport.state ~= "ready" then
        if snapshot then probe(false) end       -- first contact only after the server has sent state
        return
    end
    if snapshot and now() - snapshotAt > STALE_SNAPSHOT_MS then
        -- The feed went quiet (server stalled, reconnecting): overrides lapse locally.
        if deadlines.forced then deadlines.forced = 0 end
        if deadlines.level then deadlines.level = 0 end
    end
    push(false)
    local t = now()
    if t - lastStatusAt >= (tonumber(cfg.statusPollMs) or 5000) then lastStatusAt = t; pollStatus() end
end

NativeHud.Tick = tick   -- exposed for the test suite

AddEventHandler("onClientResourceStart", function(name)
    if name ~= GetCurrentResourceName() or started then return end
    started = true
    loadPrefs()
    CreateThread(function()
        while started do
            local ok, err = pcall(tick)
            if not ok then print("[rpcore] native HUD tick failed: " .. tostring(err)) end
            Wait(250)
        end
    end)
end)

AddEventHandler("onClientResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    started = false
    if transport.state == "ready" then invoke("RPCoreHudClear") end   -- leave no bars/effects behind
end)

-- ── player commands and diagnostics ─────────────────────────────────────────

local function toggleCommand(name, label)
    RegisterCommand("rpcore." .. name, function(_, args)
        local arg = type(args) == "table" and tostring(args[1] or "toggle"):lower() or "toggle"
        if arg == "on" then prefs[name] = true
        elseif arg == "off" then prefs[name] = false
        elseif arg == "toggle" then prefs[name] = not prefs[name]
        else say(("usage: /rpcore.%s [on|off|toggle]"):format(name)) return end
        savePrefs()
        push(true)
        say(("%s bar %s (saved). A server can still hide it."):format(label, prefs[name] and "ON" or "OFF"))
    end, false, {
        help = ("Show or hide the %s bar (saved on this client)"):format(label:lower()),
        parameters = { { name = "state", optional = true, help = "on | off | toggle" } },
    })
end
toggleCommand("hunger", "Hunger")
toggleCommand("thirst", "Thirst")

function NativeHud.Status()
    return { transport = transport, game = gameStatus, prefs = prefs, configured = configured }
end

RegisterCommand("rpcore.hud.native", function()
    say(("native HUD transport: %s%s | calls %d, failures %d"):format(transport.state,
        transport.reason and (" (" .. transport.reason .. ")") or "", transport.calls, transport.failures))
    say(("bars: hunger %s, thirst %s (player toggles) | server snapshot: %s"):format(
        prefs.hunger and "on" or "off", prefs.thirst and "on" or "off", snapshot and "received" or "none yet"))
    local value, tier = effectivePsychosis()
    if value then
        local labels = cfgOf(snapshot) and cfgOf(snapshot).labels or {}
        say(("cyberpsychosis: %.1f / tier %d (%s)%s"):format(value, tier, tostring(labels[tier] or tiers[tier].label),
            serverEnabled() and "" or " [bars switched off by the server]"))
    end
    if gameStatus.raw ~= "" then say("game side: " .. gameStatus.raw) end
    say("If GlitchBegone (or a similar mod) is installed it removes the fullscreen glitch assets, so Blackwall/relic visuals will be weaker or absent.")
end, false, { help = "Report the native HUD bridge status" })

RegisterCommand("rpcore.hud.native.ping", function()
    transport.state, transport.reason, transport.nextProbeAt = "unprobed", nil, 0
    local ok = probe(true)
    say(ok and "native HUD ping OK" or ("native HUD ping failed: " .. tostring(transport.reason)))
end, false, { help = "Retry the native HUD bridge probe now" })
