-- simnc_hud/client/main.lua  (v3, OPX)
--
--   top-right    -> character name, eddies, bank, job, weather + clock
--   bottom-left  -> health, armor, stamina, humanity, food / water / energy
--   bottom-mid   -> SIMNC logo
--   bottom-right -> weapon card (client/weapon.lua, web/weapon.html)
--
-- RPCore owns this player-facing HUD. It receives server-owned snapshots via
-- EventCore and renders them without reading another resource's client state.
-- The game's own health/stamina/weapon widgets are hidden by OPX's HUD module
-- (config/hud.lua VANILLA), so nothing here claims them.

RPCore = RPCore or {}
RPCore.Hud = RPCore.Hud or {}

local page = nil
local manualOff = false
local lastShown = nil
local last = {}
local currentState = nil
local lastFeedEpoch = nil
local lastFeedSequence = 0

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
    local stats = type(currentState) == "table" and currentState.stats or nil
    if type(stats) ~= "table" or type(stats.health) ~= "number" or type(stats.healthMax) ~= "number" then return end
    local payload = {
        health = stats.health,
        healthMax = stats.healthMax,
        armor = stats.armor,
        stamina = stats.stamina,
        staminaMax = stats.staminaMax,
    }
    local signature = not force and table.concat({
        math.floor(tonumber(payload.health) or 0), math.floor(tonumber(payload.healthMax) or 0),
        math.floor(tonumber(payload.armor) or 0), math.floor(tonumber(payload.stamina) or -1),
        math.floor(tonumber(payload.staminaMax) or -1) }, "|") or nil
    send("simnc:stats", payload, signature)
end

RPCore.Hud.State = function() return currentState end
-- What is actually on screen right now (the weapon card follows it).
RPCore.Hud.Shown = function() return lastShown == true end

local function apply(state, force)
    currentState = state
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
    local survival = type(state.survival) == "table" and state.survival or {}
    if state.cash ~= nil or state.bank ~= nil or state.job ~= nil or needs.hunger ~= nil
        or needs.thirst ~= nil or needs.energy ~= nil or state.food ~= nil or state.water ~= nil
        or state.breath ~= nil or state.level ~= nil or state.survival ~= nil then
        local rp = {
            name = state.name, cash = state.cash, bank = state.bank,
            job = state.job, jobGrade = state.jobGrade, onDuty = state.onDuty == true,
            level = state.level, breath = state.breath, breathMax = state.breathMax,
            food = survival.hunger or needs.hunger or state.food,
            foodMax = survival.hungerMax or needs.hungerMax or state.foodMax,
            water = survival.thirst or needs.thirst or state.water,
            waterMax = survival.thirstMax or needs.thirstMax or state.waterMax,
            sanity = survival.sanity or state.sanity,
            sanityMax = survival.sanityMax or state.sanityMax,
            energy = needs.energy,
        }
        send("simnc:rp", rp, table.concat({ tostring(rp.name), tostring(rp.cash), tostring(rp.bank), tostring(rp.job),
            tostring(rp.jobGrade), tostring(rp.onDuty), tostring(rp.level), tostring(rp.breath),
            tostring(rp.breathMax), tostring(rp.foodMax), tostring(rp.waterMax),
            math.floor(tonumber(rp.food) or -1), math.floor(tonumber(rp.water) or -1),
            math.floor(tonumber(rp.energy) or -1), math.floor(tonumber(rp.sanity) or -1),
            math.floor(tonumber(rp.sanityMax) or -1) }, "|"))
    elseif state.name then
        send("simnc:character", { name = state.name }, tostring(state.name))
    end

    local h = state.humanity
    if type(h) == "table" and tonumber(h.current) and tonumber(h.ceiling) then
        send("simnc:humanity", { current = h.current, ceiling = h.ceiling }, h.current .. "/" .. h.ceiling)
    end

    local w = state.weather
    if type(w) == "table" then
        send("simnc:weather", { weather = w.weather, hour = w.hour, minute = w.minute },
            tostring(w.weather) .. tostring(w.hour) .. ":" .. tostring(w.minute))
    end
    sendStats(force)
end

local function refreshState(force)
    apply(currentState, force)
end

RegisterNetEvent("eventcore:net:state:update", function(packet)
    if type(packet) ~= "table" or packet.protocolVersion ~= 1
        or packet.channel ~= "rpcore.hud" or packet.schemaVersion ~= 1
        or packet.publisher ~= "rpcore" or type(packet.epoch) ~= "string"
        or type(packet.sequence) ~= "number" or packet.sequence < 1
        or packet.sequence % 1 ~= 0
        or type(packet.state) ~= "table" then return end
    if packet.epoch == lastFeedEpoch and packet.sequence <= lastFeedSequence then return end
    lastFeedEpoch = packet.epoch
    lastFeedSequence = packet.sequence
    currentState = packet.visible and packet.state or nil
    apply(currentState, true)
end)

local function createPage()
    local surface, err = Open77.webui.create({
        entry = "web/simnc/index.html",
        layer = "hud",
        zIndex = 800, -- above the OPX HUD (700), below the crosshair (850)
        transparent = true,
        visible = true,
    })
    if not surface then
        print("[rpcore] SIMNC HUD page failed: " .. tostring(err))
        return
    end
    page = surface
    lastShown = nil
    if RPCore.Layout then RPCore.Layout.RegisterSurface("vitals", page, { "vitals", "occupation" }) end

    -- RPCore replaces these native widgets with its own HUD. Keep the native
    -- crosshair visible in first person; the custom crosshair only covers the
    -- third-person case where Open77's reticle is not already drawing.
    for _, component in ipairs({ "health", "stamina", "weapon" }) do
        local ok, reason = Open77.hud.setVisible(component, false)
        if not ok then
            print("[rpcore] could not hide native " .. component .. " HUD: " .. tostring(reason))
        end
    end

    -- The page asks for its first frame once its listeners exist.
    page:on("simnc:ready", function()
        print("[rpcore] SIMNC HUD WebUI is ready")
        lastShown = nil
        refreshState(true)
    end)

    CreateThread(function()
        Wait(5000)
        if page == surface and not pageReady then
            print("[rpcore] SIMNC HUD WebUI did not report ready; check the page and web_files")
        end
    end)

end

AddEventHandler("open77:menuStateChanged", function(open, _pauseMenu, source)
    local isOpen = open == true or tostring(open) == "1" or tostring(open) == "true"
    menuCovered = isOpen and HIDE_FOR[tostring(source)] == true
    refreshState(false)
end)

AddEventHandler("onClientResourceStart", function(name)
    if name == GetCurrentResourceName() then createPage() end
end)

AddEventHandler("onClientResourceStop", function(name)
    if name ~= GetCurrentResourceName() or not page then return end
    page:destroy()
    page = nil
end)

-- For screenshots and testing: /rpcore.hud turns the RPCore HUD off and on.
RegisterCommand("rpcore.hud", function()
    manualOff = not manualOff
    lastShown = nil
    refreshState(true)
    if RPCore.Hud.OnManual then RPCore.Hud.OnManual(manualOff) end
end, false)

-- RPCore's menu key and HUD visibility action use the same behavior.
RPCore.Hud.Toggle = function()
    manualOff = not manualOff
    lastShown = nil
    refreshState(true)
    if RPCore.Hud.OnManual then RPCore.Hud.OnManual(manualOff) end
    return not manualOff
end
