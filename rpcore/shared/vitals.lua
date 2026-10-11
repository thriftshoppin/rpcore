--- RPCore vitals logic shared by server and client (pure functions, no host calls).
--
-- Three native HUD bars are driven from this module's vocabulary:
--   hunger     drains toward EMPTY   (provider pushes the value)
--   thirst     drains toward EMPTY   (provider pushes the value)
--   psychosis  FILLS toward 100      (cyberpsychosis danger meter, 5 tiers)
--
-- `sanity` is a DEPRECATED alias for `psychosis`. It maps to the same number in
-- the same direction (0 calm .. 100 severe). It is never inverted.
RPCore = RPCore or {}
local Vitals = {}
RPCore.Vitals = Vitals

Vitals.BARS = { hunger = true, thirst = true, psychosis = true }
Vitals.TOGGLEABLE = { hunger = true, thirst = true }     -- psychosis has no player toggle
Vitals.ALIASES = { sanity = "psychosis" }                -- deprecated names -> canonical
Vitals.TIER_IDS = { "stable", "strained", "fraying", "breach", "psychosis" }

local DEFAULT_FROM = { 0, 25, 50, 75, 90 }
local DEFAULT_LABEL = { "Stable", "Strained", "Fraying", "Breach", "Psychosis" }

function Vitals.Finite(value)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
end

function Vitals.Clamp(value, lo, hi) return math.max(lo, math.min(hi, value)) end

--- Canonical bar name for a request name, plus whether it was a deprecated alias.
function Vitals.CanonicalBar(name)
    if type(name) ~= "string" then return nil end
    local alias = Vitals.ALIASES[name]
    if alias then return alias, name end
    if Vitals.BARS[name] then return name, nil end
    return nil
end

--- Build the validated tier table from Config.psychosis.
-- Returns tiers, problem. `problem` is nil when the configuration was accepted;
-- otherwise the defaults are returned and `problem` says why the config was refused.
-- Each tier: { index, id, label, from, to } where `to` is the next tier's `from`
-- (the last tier ends at `max`). A tier owns [from, to); the last owns [from, max].
function Vitals.BuildTiers(cfg)
    cfg = type(cfg) == "table" and cfg or {}
    local max = Vitals.Finite(cfg.max) or 100
    local list, problem = cfg.tiers, nil
    local out = {}

    local function defaults(why)
        out = {}
        for i, id in ipairs(Vitals.TIER_IDS) do
            out[i] = { index = i, id = id, label = DEFAULT_LABEL[i], from = DEFAULT_FROM[i] * max / 100 }
        end
        return why
    end

    if type(list) ~= "table" or #list ~= #Vitals.TIER_IDS then
        problem = defaults("psychosis.tiers must list exactly 5 tiers")
    else
        local last = -1
        for i, id in ipairs(Vitals.TIER_IDS) do
            local t = list[i]
            local from = type(t) == "table" and Vitals.Finite(t.from) or nil
            if type(t) ~= "table" or t.id ~= id then problem = defaults(("tier %d must have id '%s'"):format(i, id)) break end
            if not from or from < 0 or from >= max then problem = defaults(("tier '%s' has an invalid 'from'"):format(id)) break end
            if (i == 1 and from ~= 0) or (i > 1 and from <= last) then
                problem = defaults("tier 'from' values must start at 0 and strictly ascend")
                break
            end
            last = from
            out[i] = { index = i, id = id, label = type(t.label) == "string" and t.label or DEFAULT_LABEL[i], from = from }
        end
    end

    for i, tier in ipairs(out) do tier.to = out[i + 1] and out[i + 1].from or max end
    return out, problem
end

--- Tier index for `value` with downward hysteresis.
-- Rising crosses a boundary exactly at `from`; falling must go `hysteresis`
-- points BELOW the tier's `from` before the tier drops, so a value sitting on a
-- boundary cannot flicker the effects.
function Vitals.TierIndexFor(tiers, value, previous, hysteresis)
    value = Vitals.Finite(value) or 0
    local index = 1
    for i, tier in ipairs(tiers) do
        if value >= tier.from then index = i end
    end
    previous = tonumber(previous)
    hysteresis = Vitals.Finite(hysteresis) or 0
    if previous and previous > index and previous >= 1 and previous <= #tiers then
        if value >= tiers[previous].from - hysteresis then index = previous end
    end
    return index
end

function Vitals.TierIndexById(tiers, id)
    if type(id) == "number" then
        if id % 1 == 0 and id >= 1 and id <= #tiers then return id end
        return nil
    end
    if type(id) ~= "string" then return nil end
    for i, tier in ipairs(tiers) do if tier.id == id then return i end end
    return nil
end

--- Normalise an override lifetime to whole seconds, bounded by config.
-- Every override expires; a missing ttl takes `defaultSeconds`.
-- Returns seconds or nil + reason.
function Vitals.NormalizeTtl(ttl, overridesCfg)
    local cfg = type(overridesCfg) == "table" and overridesCfg or {}
    local maxSeconds = Vitals.Finite(cfg.maxSeconds) or 900
    local default = Vitals.Finite(cfg.defaultSeconds) or 120
    if ttl == nil then return math.min(default, maxSeconds) end
    ttl = Vitals.Finite(ttl)
    if not ttl or ttl <= 0 then return nil, "invalid_ttl" end
    return math.min(ttl, maxSeconds)
end

--- Overrides carry a short free-text source for diagnostics ("mission:q101").
function Vitals.CleanSource(source)
    if source == nil then return "unspecified" end
    if type(source) ~= "string" or #source == 0 or #source > 64 or not source:match("^[%w_%-%.:/ ]+$") then return nil end
    return source
end

--- Old web-page effect levels (0..1) derived from a tier, for the fallback page only.
function Vitals.LegacyFx(tierIndex)
    local blackwall = ({ 0, 0, 0.4, 0.8, 1 })[tierIndex or 1] or 0
    local relic = tierIndex == 5 and 0.6 or 0
    return { blackwall = blackwall, relic = relic }
end

return Vitals
