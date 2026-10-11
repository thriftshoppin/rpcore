--- Server-owned vitals: hunger, thirst and the cyberpsychosis meter.
--
-- RPCore SIMULATES NOTHING. A provider pushes values in (SetVital / SetPsychosis);
-- this module validates them, derives the automatic psychosis tier, applies
-- mission/EventCore overrides and publishes the result inside the normal
-- `rpcore.hud` snapshot (server/hud_state.lua). The client forwards it to the
-- game's own HUD controller (client/native_hud.lua -> redscript pack).
--
-- Handles (all writes obey Config.exports.allowedCallers via RPCore.GuardExport;
-- all return `true` or `nil, reason`):
--   exports.rpcore:SetVital(player, vital, value, max?)
--   exports.rpcore:SetPsychosis(player, value, opts?)     opts = { max?, ttl?, source? } | ttlSeconds
--   exports.rpcore:ForceTier(player, tier, ttl?, source?)
--   exports.rpcore:ReleaseTier(player, which?)            "all" (default) | "tier" | "level"
--   exports.rpcore:SetBarVisible(player, bar, visible, ttl?, source?)
--   exports.rpcore:GetVitals(player)                      (open read)
--   exports.rpcore:GetPsychosisTiers()                    (open read)
--
-- Precedence for the cyberpsychosis meter, highest first:
--   1. ForceTier         (a mission pins the tier; the bar is shown clamped inside it)
--   2. SetPsychosis+ttl  (a timed level override; tier follows the overridden level)
--   3. the provider's baseline value from SetVital/SetPsychosis (automatic tier)
-- EVERY override expires (Warden tunables overrideDefaultSeconds / overrideMaxSeconds). Releasing one returns control to the next
-- layer down, ending at the automatic tier.
RPCore = RPCore or {}
local Config = RPCore.Config
local V = RPCore.Vitals

local Server = {}
V.Server = Server

-- ── operator tunables (Warden -> Tuning) ────────────────────────────────────
-- `Tune.key` reads through to the host on every access, so values are read at the point of
-- use and never cached in a file-scope local. Without Open77.tunables the declared defaults apply.
local Tune
if Open77 and type(Open77.tunables) == "table" and type(Open77.tunables.declare) == "function" then
    local ok, proxy = pcall(Open77.tunables.declare, Config.tunables)
    if ok then Tune = proxy else RPCore.Log.warn("tunables declaration refused: " .. tostring(proxy)) end
end
local function T(key)
    if Tune then
        local ok, value = pcall(function() return Tune[key] end)
        if ok and value ~= nil then return value end
    end
    return Config.tunables[key].value
end
Server.Tunable = T

local PSY_MAX = V.Finite(Config.psychosis and Config.psychosis.max) or 100

local cachedTiers, cachedSig, warnedSig
--- Validated tier table from the CURRENT tunables (rebuilt only when they change).
local function tiers()
    local from = { 0, T("strainedFrom"), T("frayingFrom"), T("breachFrom"), T("psychosisFrom") }
    local sig = table.concat(from, ",")
    if sig ~= cachedSig then
        local list = {}
        for i, id in ipairs(V.TIER_IDS) do
            local cfgTier = Config.psychosis.tiers[i] or {}
            list[i] = { id = id, label = cfgTier.label, from = from[i] }
        end
        local built, problem = V.BuildTiers({ max = PSY_MAX, tiers = list })
        if problem and warnedSig ~= sig then
            warnedSig = sig
            RPCore.Log.warn("psychosis tier tunables refused, using defaults until fixed: " .. problem)
        end
        cachedTiers, cachedSig = built, sig
    end
    return cachedTiers
end
Server.Tiers = tiers

local function hysteresis() return V.Finite(T("hysteresis")) or 0 end
local function overridesCfg() return { defaultSeconds = T("overrideDefaultSeconds"), maxSeconds = T("overrideMaxSeconds") } end

local byPlayer = {}
local warnedAlias = false

--- Set by server/hud_state.lua: asks for a (deferred, non-yielding) snapshot publish.
Server.OnChange = function() end

local function now() return RPCore.Now() end

local function playerId(value)
    local id = tonumber(value)
    if not id or id < 1 or id % 1 ~= 0 then return nil end
    return id
end

local function stateFor(id)
    local s = byPlayer[id]
    if not s then
        s = { autoTier = 1, hidden = {}, rev = 0 }
        byPlayer[id] = s
    end
    return s
end

local function touched(id, s)
    s.rev = s.rev + 1
    Server.OnChange(id)
end

local function warnAlias(alias)
    if warnedAlias then return end
    warnedAlias = true
    RPCore.Log.warn(("'%s' is a deprecated alias for 'psychosis' (same 0-100 direction, not inverted). Use 'psychosis'."):format(alias))
end

--- Scale an incoming psychosis value onto the configured 0..PSY_MAX scale.
local function psychosisValue(value, max)
    if max ~= nil and max ~= PSY_MAX then value = value * PSY_MAX / max end
    return V.Clamp(value, 0, PSY_MAX)
end

local function ttlToExpiry(ttl)
    local seconds, why = V.NormalizeTtl(ttl, overridesCfg())
    if not seconds then return nil, why end
    return now() + math.floor(seconds * 1000), seconds
end

-- ── writes ──────────────────────────────────────────────────────────────────

function Server.SetVital(rawId, vital, value, max)
    local id = playerId(rawId)
    if not id then return nil, "invalid_player_id" end
    local bar, alias = V.CanonicalBar(vital)
    if not bar then return nil, "unknown_vital" end
    if alias then warnAlias(alias) end
    local v = V.Finite(value)
    if not v then return nil, "invalid_value" end
    local m = max ~= nil and V.Finite(max) or nil
    if max ~= nil and (not m or m <= 0) then return nil, "invalid_max" end

    local s = stateFor(id)
    if bar == "psychosis" then
        v = psychosisValue(v, m)
        s.psychosis = { value = v, max = PSY_MAX }
        s.autoTier = V.TierIndexFor(tiers(), v, s.autoTier, hysteresis())
    else
        local current = s[bar]
        m = m or (current and current.max) or tonumber(Config.vitals[bar].max) or 100
        s[bar] = { value = V.Clamp(v, 0, m), max = m }
    end
    touched(id, s)
    return true
end

function Server.SetPsychosis(rawId, value, opts)
    local id = playerId(rawId)
    if not id then return nil, "invalid_player_id" end
    if type(opts) == "number" then opts = { ttl = opts } end
    if opts ~= nil and type(opts) ~= "table" then return nil, "invalid_options" end
    opts = opts or {}
    local v = V.Finite(value)
    if not v then return nil, "invalid_value" end
    local m = opts.max ~= nil and V.Finite(opts.max) or nil
    if opts.max ~= nil and (not m or m <= 0) then return nil, "invalid_max" end

    if opts.ttl == nil and opts.override ~= true then
        return Server.SetVital(id, "psychosis", v, m)       -- plain provider baseline
    end
    local source = V.CleanSource(opts.source)
    if not source then return nil, "invalid_source" end
    local expires, why = ttlToExpiry(opts.ttl)
    if not expires then return nil, why end
    local s = stateFor(id)
    s.levelOverride = { value = psychosisValue(v, m), expires = expires, source = source }
    touched(id, s)
    return true
end

function Server.ForceTier(rawId, tier, ttl, source)
    local id = playerId(rawId)
    if not id then return nil, "invalid_player_id" end
    local index = V.TierIndexById(tiers(), tier)
    if not index then return nil, "unknown_tier" end
    local clean = V.CleanSource(source)
    if not clean then return nil, "invalid_source" end
    local expires, why = ttlToExpiry(ttl)
    if not expires then return nil, why end
    local s = stateFor(id)
    s.tierOverride = { index = index, expires = expires, source = clean }
    touched(id, s)
    return true
end

function Server.ReleaseTier(rawId, which)
    local id = playerId(rawId)
    if not id then return nil, "invalid_player_id" end
    if which == nil then which = "all" end
    if which ~= "all" and which ~= "tier" and which ~= "level" then return nil, "invalid_release" end
    local s = byPlayer[id]
    if not s then return true end
    if which == "all" or which == "tier" then s.tierOverride = nil end
    if which == "all" or which == "level" then s.levelOverride = nil end
    touched(id, s)
    return true
end

function Server.SetBarVisible(rawId, bar, visible, ttl, source)
    local id = playerId(rawId)
    if not id then return nil, "invalid_player_id" end
    local canonical, alias = V.CanonicalBar(bar)
    if not canonical then return nil, "unknown_bar" end
    if alias then warnAlias(alias) end
    if visible ~= nil and type(visible) ~= "boolean" then return nil, "invalid_visible" end
    local s = stateFor(id)
    if visible == false then
        local clean = V.CleanSource(source)
        if not clean then return nil, "invalid_source" end
        local expires, why = ttlToExpiry(ttl)
        if not expires then return nil, why end
        s.hidden[canonical] = { expires = expires, source = clean }
    else
        s.hidden[canonical] = nil       -- true / nil: release the force-hide (the player's own toggle decides)
    end
    touched(id, s)
    return true
end

function Server.Clear(rawId)
    local id = playerId(rawId)
    if not id then return nil, "invalid_player_id" end
    if byPlayer[id] then byPlayer[id] = nil; Server.OnChange(id) end
    return true
end

-- ── expiry ──────────────────────────────────────────────────────────────────

--- Drop expired overrides. Returns the player ids whose state changed.
function Server.Tick()
    local t, changed = now(), {}
    for id, s in pairs(byPlayer) do
        local dirty = false
        if s.tierOverride and s.tierOverride.expires <= t then s.tierOverride = nil; dirty = true end
        if s.levelOverride and s.levelOverride.expires <= t then s.levelOverride = nil; dirty = true end
        for bar, h in pairs(s.hidden) do
            if h.expires <= t then s.hidden[bar] = nil; dirty = true end
        end
        if dirty then s.rev = s.rev + 1; changed[#changed + 1] = id end
    end
    return changed
end

--- Presentation config the client forwards to the game side (all operator-tunable values
--- that the HUD needs). Sent inside every snapshot so a live tuning change reaches players.
function Server.ClientConfig()
    local list, bounds, labels = tiers(), {}, {}
    for i, tier in ipairs(list) do
        labels[i] = tier.label
        if i > 1 then bounds[#bounds + 1] = tier.from / PSY_MAX end
    end
    return {
        enabled = T("nativeBarsEnabled") == true,
        showWithoutData = T("showBarsWithoutData") == true,
        bounds = bounds, labels = labels,
        relicEnabled = T("relicEnabled") == true,
        relicRecord = tostring(T("relicRecord")),
    }
end

-- ── read model ──────────────────────────────────────────────────────────────

local function remaining(entry, t)
    if not entry then return nil end
    return math.max(0, entry.expires - t)
end

local function barView(s, bar)
    local d = s[bar]
    local h = s.hidden[bar]
    local t = now()
    return {
        value = d and d.value or 0,
        max = d and d.max or (tonumber(Config.vitals[bar].max) or 100),
        hasData = d ~= nil,
        hidden = h ~= nil,
        hiddenTtlMs = remaining(h, t),
    }
end

--- Plain-data view of one player's vitals (what the client receives).
function Server.View(rawId)
    local id = playerId(rawId)
    local s = id and byPlayer[id] or nil
    if not s then s = { autoTier = 1, hidden = {}, rev = 0 } end
    local t = now()

    local tierList = tiers()
    local base = s.psychosis and s.psychosis.value or nil
    local value, tierIndex, forced, level = base, s.autoTier, false, false
    if s.levelOverride then
        value = s.levelOverride.value
        tierIndex = V.TierIndexFor(tierList, value, nil, 0)
        level = true
    end
    if s.tierOverride then
        local tier = tierList[s.tierOverride.index]
        tierIndex = tier.index
        forced = true
        -- The bar must agree with the pinned tier: show the level clamped inside it.
        value = V.Clamp(value or tier.from, tier.from, tier.to)
    end

    local tier = tierList[tierIndex] or tierList[1]
    local hidden = s.hidden.psychosis
    local psychosis = {
        value = value or 0,
        max = PSY_MAX,
        base = base,
        hasData = value ~= nil,
        tier = tier.index,
        tierId = tier.id,
        autoTier = s.autoTier,
        forced = forced,
        forcedTtlMs = forced and remaining(s.tierOverride, t) or nil,
        level = level,
        levelTtlMs = level and remaining(s.levelOverride, t) or nil,
        hidden = hidden ~= nil,
        hiddenTtlMs = remaining(hidden, t),
    }
    return {
        rev = s.rev,
        cfg = Server.ClientConfig(),
        hunger = barView(s, "hunger"),
        thirst = barView(s, "thirst"),
        psychosis = psychosis,
    }
end

-- ── exports ─────────────────────────────────────────────────────────────────

local function guarded(fn)
    return function(...)
        local caller, why = RPCore.GuardExport()
        if not caller then return nil, why end
        return fn(...)
    end
end

exports("SetVital", guarded(Server.SetVital))
exports("SetPsychosis", guarded(Server.SetPsychosis))
exports("ForceTier", guarded(Server.ForceTier))
exports("ReleaseTier", guarded(Server.ReleaseTier))
exports("SetBarVisible", guarded(Server.SetBarVisible))

exports("GetVitals", function(rawId)
    local id = playerId(rawId)
    if not id then return nil, "invalid_player_id" end
    return Server.View(id)
end)

exports("GetPsychosisTiers", function()
    local out = {}
    for i, tier in ipairs(tiers()) do
        out[i] = { index = tier.index, id = tier.id, label = tier.label, from = tier.from, to = tier.to }
    end
    return out
end)

AddEventHandler("playerDropped", function()
    local id = playerId(source)
    if id then byPlayer[id] = nil end
end)
