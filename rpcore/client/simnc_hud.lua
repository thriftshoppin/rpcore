-- simnc_hud/client/main.lua  (v3, OPX)
--
--   top-right    -> character name, eddies, bank, job, weather + clock
--   bottom-left  -> health, armor, stamina, humanity, food / water / energy
--   bottom-mid   -> SIMNC logo
--   bottom-right -> weapon card (client/weapon.lua, web/weapon.html)
--
-- OPX decides WHEN the HUD is on screen (logged in, not downed, no select
-- screen / creator / menu covering it) and holds all character data. This
-- resource only asks it, through simnc_core's `SimncState` export, and draws.
-- The game's own health/stamina/weapon widgets are hidden by OPX's HUD module
-- (config/hud.lua VANILLA), so nothing here claims them.

SimncHud = SimncHud or {}

local page = nil
local manualOff = false
local lastShown = nil
local last = {}

local STATE_MS = 250

-- Game screens the HUD steps aside for: the mirror editor (face, hair), the
-- character creator, the game's own menus (map, inventory, pause) and photo
-- mode. OPX already hides it for its own screens (select, appearance panel,
-- fitting room); these are the game's, which only this signal reports.
local HIDE_FOR = { appearance = true, creator = true, vanilla = true, photoMode = true }
local menuCovered = false

local function send(channel, payload, signature)
    if not page then return end
    if signature ~= nil and last[channel] == signature then return end
    last[channel] = signature
    page:send(channel, payload)
end

local function sendStats(force)
    if not page then return end
    local stats = Open77.stats.get()
    if type(stats) ~= "table" or type(stats.health) ~= "table" then return end
    local payload = {
        health = stats.health.current,
        healthMax = stats.health.maximum,
        armor = stats.armor,
        stamina = type(stats.stamina) == "table" and stats.stamina.current or nil,
        staminaMax = type(stats.stamina) == "table" and stats.stamina.maximum or nil,
    }
    local signature = not force and table.concat({
        math.floor(tonumber(payload.health) or 0), math.floor(tonumber(payload.healthMax) or 0),
        math.floor(tonumber(payload.armor) or 0), math.floor(tonumber(payload.stamina) or -1),
        math.floor(tonumber(payload.staminaMax) or -1) }, "|") or nil
    send("simnc:stats", payload, signature)
end

--- What OPX says, or nil when simnc_core is not answering yet.
local function readState()
    if type(Open77.exports) ~= "table" or type(Open77.exports.callSync) ~= "function" then return nil end
    local ok, state = pcall(Open77.exports.callSync, "simnc_core", "SimncState")
    if ok and type(state) == "table" then return state end
    return nil
end

SimncHud.State = function() return SimncHud.last end
-- What is actually on screen right now (the weapon card follows it).
SimncHud.Shown = function() return lastShown == true end

local function apply(state, force)
    SimncHud.last = state
    local shown = state ~= nil and state.shown == true and not manualOff and not menuCovered
    if shown ~= lastShown then
        lastShown = shown
        -- The SURFACE stays up for the whole session; the page hides its own
        -- content. Toggling a surface with show()/hide() -- and creating it
        -- hidden -- is the path OPX warns loses the race and never paints.
        if page then page:send("simnc:visible", { shown = shown }) end
        if shown then force = true end
    end
    if not shown then return end
    if force then last = {} end

    local needs = type(state.needs) == "table" and state.needs or {}
    local rp = {
        name = state.name, cash = state.cash, bank = state.bank,
        job = state.job, jobGrade = state.jobGrade, onDuty = state.onDuty == true,
        food = needs.hunger, water = needs.thirst, energy = needs.energy,
    }
    send("simnc:rp", rp, table.concat({ tostring(rp.name), tostring(rp.cash), tostring(rp.bank), tostring(rp.job),
        tostring(rp.jobGrade), tostring(rp.onDuty), math.floor(tonumber(rp.food) or -1),
        math.floor(tonumber(rp.water) or -1), math.floor(tonumber(rp.energy) or -1) }, "|"))

    local h = state.humanity
    if type(h) == "table" and tonumber(h.current) and tonumber(h.ceiling) then
        send("simnc:humanity", { current = h.current, ceiling = h.ceiling }, h.current .. "/" .. h.ceiling)
    end

    local w = state.weather
    if type(w) == "table" then
        send("simnc:weather", { weather = w.weather, hour = w.hour, minute = w.minute },
            tostring(w.weather) .. tostring(w.hour) .. ":" .. tostring(w.minute))
    end
    send("simnc:vehicle", { active = state.inVehicle == true }, tostring(state.inVehicle == true))
    -- SIMNC: the logo can be switched off in the F5 settings (simnc_core chat/client/prefs.lua).
    local logo = not (type(state.prefs) == "table" and state.prefs.hudLogo == "off")
    send("simnc:prefs", { logo = logo }, tostring(logo))
    sendStats(force)
end

local function createPage()
    local surface, err = Open77.webui.create({
        entry = "web/simnc/index.html",
        layer = "hud",
        zIndex = 600, -- above the blood layer (10), below OPX (700) and the crosshair (850)
        transparent = true,
        visible = true,
    })
    if not surface then
        print("[rpcore] SIMNC HUD page failed: " .. tostring(err))
        return
    end
    page = surface
    lastShown = nil

    -- The page asks for its first frame once its listeners exist.
    page:on("simnc:ready", function() lastShown = nil apply(readState(), true) end)

    CreateThread(function()
        while page ~= nil do
            apply(readState(), false)
            Wait(STATE_MS)
        end
    end)
    -- Vitals move faster than the rest; sampled on their own, sent only on change.
    CreateThread(function()
        while page ~= nil do
            if lastShown then sendStats(false) end
            Wait(50)
        end
    end)
end

AddEventHandler("open77:menuStateChanged", function(open, _pauseMenu, source)
    local isOpen = open == true or tostring(open) == "1" or tostring(open) == "true"
    menuCovered = isOpen and HIDE_FOR[tostring(source)] == true
    apply(readState(), false)
end)

RegisterNetEvent("simnc:stats:poke", function() sendStats(true) end)
AddEventHandler("open77:playerStatsChanged", function() sendStats(false) end)

AddEventHandler("onClientResourceStart", function(name)
    if name == GetCurrentResourceName() then createPage() end
end)

AddEventHandler("onClientResourceStop", function(name)
    if name ~= GetCurrentResourceName() or not page then return end
    page:destroy()
    page = nil
end)

-- For screenshots and testing: /simnchud turns the whole SIMNC HUD off and on.
RegisterCommand("simnchud", function()
    manualOff = not manualOff
    lastShown = nil
    apply(readState(), true)
    if SimncHud.OnManual then SimncHud.OnManual(manualOff) end
end, false)

-- RPCore's menu key and HUD visibility action use the same behavior as the
-- legacy /simnchud command.
SimncHud.Toggle = function()
    manualOff = not manualOff
    lastShown = nil
    apply(readState(), true)
    if SimncHud.OnManual then SimncHud.OnManual(manualOff) end
    return not manualOff
end
