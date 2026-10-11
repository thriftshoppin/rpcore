-- RPCore owns the player-facing HUD view. Open77 server APIs supply the
-- authoritative session identity, life state, and vitals; EventCore owns their
-- versioned delivery to the client renderer.

local CHANNEL = "rpcore.hud"
local SCHEMA_VERSION = 1
local SAMPLE_MS = 1000
local lastPublishError = nil
local publish
-- Hunger, thirst and the cyberpsychosis meter (values, tiers, overrides, expiry) live in
-- server/vitals.lua; this file only adds them to the published snapshot.
local Vitals = RPCore.Vitals.Server

local function playerId(value)
    local id = tonumber(value)
    if not id or id < 1 or id % 1 ~= 0 then return nil end
    return id
end

local function finite(value)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
end

local function statsFor(id)
    if not (Open77 and Open77.stats and type(Open77.stats.get) == "function") then return nil end
    local ok, raw = pcall(Open77.stats.get, id)
    if not ok or type(raw) ~= "table" then return nil end
    local health = type(raw.health) == "table" and raw.health or {}
    local stamina = type(raw.stamina) == "table" and raw.stamina or {}
    local currentHealth = finite(health.current) or finite(health.value)
    local healthMax = finite(health.maximum) or finite(health.max)
    if not currentHealth or not healthMax then return nil end
    return {
        health = currentHealth,
        healthMax = healthMax,
        armor = finite(raw.armor),
        stamina = finite(stamina.current) or finite(stamina.value),
        staminaMax = finite(stamina.maximum) or finite(stamina.max),
    }
end

local function buildView(id)
    if not (Open77 and Open77.players) then return nil end
    local nameRead, name = pcall(Open77.players.name, id)
    local lifeRead, life = pcall(Open77.players.getLifeState, id)
    if not nameRead or type(name) ~= "string" or not lifeRead or type(life) ~= "table" then
        return nil
    end
    local stats = statsFor(id)
    if not stats then return nil end
    local vitals = Vitals.View(id)
    -- `survival` / `psychosis` below are the LEGACY shapes, kept only so the optional
    -- web fallback page keeps working. The native bars read `vitals`.
    local survival = {}
    if vitals.hunger.hasData then survival.hunger, survival.hungerMax = vitals.hunger.value, vitals.hunger.max end
    if vitals.thirst.hasData then survival.thirst, survival.thirstMax = vitals.thirst.value, vitals.thirst.max end
    if vitals.psychosis.hasData then survival.sanity, survival.sanityMax = vitals.psychosis.value, vitals.psychosis.max end
    return {
        shown = life.phase == "alive" or life.phase == "recovering",
        down = life.phase == "dead" or life.phase == "downed",
        loggedIn = true,
        name = name,
        stats = stats,
        vitals = vitals,
        survival = survival,
        psychosis = RPCore.Vitals.LegacyFx(vitals.psychosis.tier),
        inVehicle = false,
    }
end

-- ── legacy provider API ─────────────────────────────────────────────────────
-- SetSurvivalVitals / ClearSurvivalVitals predate the native bars. They now delegate to
-- server/vitals.lua, so there is one source of truth. `sanity` is a DEPRECATED alias for
-- `psychosis` (same direction, never inverted). Writes are now guarded by
-- Config.exports.allowedCallers like every other write handle (they were open before).
local function setSurvivalVitals(rawId, values)
    if type(values) ~= "table" then return nil, "invalid_vitals" end
    local id = playerId(rawId)
    if not id then return nil, "invalid_player_id" end
    local any = false
    -- Validate everything first so a bad field cannot half-apply the update.
    for _, key in ipairs({ "hunger", "thirst", "sanity" }) do
        local value, maximum = values[key], values[key .. "Max"]
        if value ~= nil and not finite(value) then return nil, "invalid_" .. key end
        if maximum ~= nil then
            maximum = finite(maximum)
            if not maximum or maximum <= 0 then return nil, "invalid_" .. key .. "_max" end
        end
        if value ~= nil then any = true end
    end
    if not any then return nil, "no_vitals_provided" end
    for _, key in ipairs({ "hunger", "thirst", "sanity" }) do
        if values[key] ~= nil then
            local ok, reason = Vitals.SetVital(id, key, values[key], values[key .. "Max"])
            if not ok then return nil, reason end
        end
    end
    return true
end

RPCore.Hud = RPCore.Hud or {}
RPCore.Hud.SetSurvivalVitals = setSurvivalVitals
exports("SetSurvivalVitals", function(player, values)
    local caller, why = RPCore.GuardExport()
    if not caller then return nil, why end
    return setSurvivalVitals(player, values)
end)
exports("ClearSurvivalVitals", function(player)
    local caller, why = RPCore.GuardExport()
    if not caller then return nil, why end
    return Vitals.Clear(player)
end)

-- The Blackwall / relic LEVEL handles are retired: effects now follow the cyberpsychosis
-- tier (ForceTier / ReleaseTier / SetPsychosis). They refuse loudly instead of silently
-- doing nothing, so a stale caller finds out.
for _, name in ipairs({ "SetBlackwall", "SetRelicMalfunction", "GetCyberpsychosisFx" }) do
    exports(name, function() return nil, "deprecated_use_ForceTier" end)
end
exports("ClearCyberpsychosisFx", function(player)
    local caller, why = RPCore.GuardExport()
    if not caller then return nil, why end
    return Vitals.ReleaseTier(player, "all")
end)

-- Vitals writes publish through a host-managed thread: exports must not yield.
Vitals.OnChange = function(id)
    RPCore.Async("HUD vitals publish", function() publish(id) end)
end

publish = function(rawId)
    local id = playerId(rawId)
    if not id or not RPCore.EventCore then return end
    local view = buildView(id)
    if not view then return end
    local ok, reason = RPCore.EventCore.PublishClientState(id, CHANNEL, SCHEMA_VERSION, view)
    if ok ~= true then
        local message = tostring(reason or "publish_failed")
        if message ~= lastPublishError then RPCore.Log.warn("HUD state feed unavailable: " .. message) end
        lastPublishError = message
    else
        lastPublishError = nil
    end
end

local function allPlayers()
    if not (Open77 and Open77.players and type(Open77.players.all) == "function") then return {} end
    local ok, players = pcall(Open77.players.all)
    if not ok or type(players) ~= "table" then return {} end
    return players
end

AddEventHandler("open77:playerStatsChanged", function(id) publish(id or source) end)
AddEventHandler("open77:playerDied", function(id) publish(id) end)
-- (server/vitals.lua clears a dropped player's vitals itself.)

CreateThread(function()
    while true do
        -- Expire overrides first: a crashed mission must not leave a tier forced.
        Vitals.Tick()
        for _, id in ipairs(allPlayers()) do publish(id) end
        Wait(SAMPLE_MS)
    end
end)
