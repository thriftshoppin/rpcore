-- RPCore owns the player-facing HUD view. Open77 server APIs supply the
-- authoritative session identity, life state, and vitals; EventCore owns their
-- versioned delivery to the client renderer.

local CHANNEL = "rpcore.hud"
local SCHEMA_VERSION = 1
local SAMPLE_MS = 1000
local lastPublishError = nil
local survivalByPlayer = {}
local publish

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
    return {
        shown = life.phase == "alive" or life.phase == "recovering",
        down = life.phase == "dead" or life.phase == "downed",
        loggedIn = true,
        name = name,
        stats = stats,
        survival = survivalByPlayer[id] or {},
        inVehicle = false,
    }
end

local function setSurvivalVitals(rawId, values)
    local id = playerId(rawId)
    if not id then return false, "invalid_player_id" end
    if type(values) ~= "table" then return false, "invalid_vitals" end

    local current = {}
    for key, value in pairs(survivalByPlayer[id] or {}) do current[key] = value end
    local changed = false
    for _, key in ipairs({ "hunger", "thirst", "sanity" }) do
        local value = values[key]
        local maximum = values[key .. "Max"]
        if value ~= nil then
            value = finite(value)
            maximum = maximum == nil and (current[key .. "Max"] or 100) or finite(maximum)
            if not value or not maximum or maximum <= 0 then return false, "invalid_" .. key end
            current[key] = math.max(0, math.min(maximum, value))
            current[key .. "Max"] = maximum
            changed = true
        elseif maximum ~= nil then
            maximum = finite(maximum)
            if not maximum or maximum <= 0 then return false, "invalid_" .. key .. "_max" end
            current[key .. "Max"] = maximum
            if current[key] ~= nil then current[key] = math.min(current[key], maximum) end
            changed = true
        end
    end
    if not changed then return false, "no_vitals_provided" end
    survivalByPlayer[id] = current
    publish(id)
    return true
end

RPCore.Hud = RPCore.Hud or {}
RPCore.Hud.SetSurvivalVitals = setSurvivalVitals
exports("SetSurvivalVitals", setSurvivalVitals)
exports("ClearSurvivalVitals", function(rawId)
    local id = playerId(rawId)
    if not id then return false, "invalid_player_id" end
    survivalByPlayer[id] = nil
    publish(id)
    return true
end)

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
AddEventHandler("playerDropped", function()
    local id = playerId(source)
    if id then survivalByPlayer[id] = nil end
end)

CreateThread(function()
    while true do
        for _, id in ipairs(allPlayers()) do publish(id) end
        Wait(SAMPLE_MS)
    end
end)
