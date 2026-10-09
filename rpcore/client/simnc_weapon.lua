-- simnc_hud/client/weapon.lua
-- The weapon card, bottom-right: class icon, name, drawn / holstered, and the
-- magazine / reserve counter. Moved here from freeroam (which OPX replaces).
-- Reads the host's verified weapon snapshot; OPX's inventory decides what the
-- player holds and how much ammo they carry, this only shows it.

local card = nil
local ready = false
local requests = {}
local lastRequestAt = 0
local view = { equipped = false }
local lastSig = nil

local function now() return GetGameTimer() end
local function num(v, d) v = tonumber(v) return v ~= nil and v == v and v or d end
local function truthy(v) return v == true or v == 1 or v == "1" or v == "true" end

local function shown()
    local state = RPCore.Hud and RPCore.Hud.State and RPCore.Hud.State() or nil
    local hudUp = RPCore.Hud and RPCore.Hud.Shown and RPCore.Hud.Shown() or false
    -- With the HUD (so it hides in the same screens), and out of a vehicle only:
    -- OPX draws the vehicle read-out, and freeroam hid the card there too.
    -- ...and not switched off in the F5 settings.
    return hudUp and type(state) == "table" and state.inVehicle ~= true
        and not (type(state.prefs) == "table" and state.prefs.hudWeapon == "off")
end

local function push(force)
    if not card or not ready then return end
    local payload = {
        visible = shown(),
        weapon = view,
    }
    local w = view
    local sig = table.concat({ tostring(payload.visible), tostring(w.equipped), tostring(w.drawn), tostring(w.record),
        tostring(w.slot), tostring(w.magazine), tostring(w.capacity), tostring(w.reserve), tostring(w.ammoKnown) }, "|")
    if not force and sig == lastSig then return end
    lastSig = sig
    card:send("simnc:weapon", payload)
end

local function request()
    if type(Open77.weapons) ~= "table" or type(Open77.weapons.snapshot) ~= "function" then return end
    local at = now()
    if at - lastRequestAt < 180 then return end
    -- One read in flight at a time: equipment changes share the same queue.
    for id, pending in pairs(requests) do
        if at - pending.at <= 5000 then return end
        requests[id] = nil
    end
    lastRequestAt = at
    local ok, requestId = pcall(Open77.weapons.snapshot)
    if ok and requestId ~= nil then requests[tostring(requestId)] = { at = at, sawActive = false } end
end

AddEventHandler("open77:weapons:state", function(requestId, slot, record, tweakDbId,
        active, drawn, _locked, _ammoRecord, _ammoTweakDbId, _ammoTotal, ammoReserve, magazine, capacity)
    local pending = requests[tostring(requestId)]
    if pending == nil or not truthy(active) then return end
    pending.sawActive = true
    local recordName = tostring(record or "")
    local mag = math.floor(num(magazine, -1))
    local cap = math.floor(num(capacity, -1))
    view = {
        equipped = recordName ~= "" or tostring(tweakDbId or "") ~= "",
        drawn = truthy(drawn),
        slot = math.max(1, math.floor(num(slot, 1))),
        record = recordName,
        ammoKnown = mag >= 0 and cap >= 0,
        magazine = math.max(0, mag),
        capacity = math.max(0, cap),
        reserve = math.max(0, math.floor(num(ammoReserve, 0))),
    }
end)

AddEventHandler("open77:weapons:completed", function(requestId, operation, accepted)
    local id = tostring(requestId)
    local pending = requests[id]
    if pending == nil then return end
    if tostring(operation) == "snapshot" and truthy(accepted) and not pending.sawActive then
        view = { equipped = false }
    end
    requests[id] = nil
end)

local function create()
    local surface, err = Open77.webui.create({
        entry = "web/simnc/weapon.html",
        layer = "hud",
        zIndex = 600, -- above the blood layer (10)
        transparent = true,
        visible = true,
    })
    if not surface then
        print("[rpcore] weapon card failed: " .. tostring(err))
        return
    end
    card = surface
    card:on("simnc:weapon:ready", function() ready = true push(true) end)
    CreateThread(function()
        while card ~= nil do
            if shown() then request() end
            push(false)
            Wait(200)
        end
    end)
end

RPCore = RPCore or {}
RPCore.Hud = RPCore.Hud or {}
RPCore.Hud.OnManual = function() lastSig = nil push(true) end

AddEventHandler("onClientResourceStart", function(name)
    if name == GetCurrentResourceName() then create() end
end)

AddEventHandler("onClientResourceStop", function(name)
    if name ~= GetCurrentResourceName() or not card then return end
    card:destroy()
    card = nil
end)
