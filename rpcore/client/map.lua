-- RPCore's location pins use the game's own map projection and native blip
-- renderer. A Locations tab is added to the native City Map; it lists saved
-- places and can route to one without trying to redraw the game's map texture.
RPCore = RPCore or {}

local owned = {}
local locations = {}
local mapError
local editorAllowed = false
local mapPage
local mapTab
local selectLocationsAfterOpen = false
local MAX_LOCATIONS = 64

local function validPosition(position)
    if type(position) ~= "table" then return false end
    for _, axis in ipairs({ "x", "y", "z" }) do
        local value = tonumber(position[axis])
        if not value or value ~= value or value == math.huge or value == -math.huge
            or math.abs(value) > 16000 then return false end
    end
    return true
end

local function clearOwned()
    if Open77 and Open77.blips and type(Open77.blips.remove) == "function" then
        for _, id in pairs(owned) do Open77.blips.remove(id) end
    end
    owned = {}
end

local function updatePage()
    if mapPage then mapPage:send("rpcore:map:locations", { locations = locations, error = mapError, editorAllowed = editorAllowed }) end
end

local function applyLocations(snapshot)
    if type(snapshot) ~= "table" then return end
    mapError = type(snapshot.error) == "string" and snapshot.error or nil
    if type(snapshot.editorAllowed) == "boolean" then editorAllowed = snapshot.editorAllowed end
    local incoming = type(snapshot.locations) == "table" and snapshot.locations or {}
    locations = {}
    clearOwned()
    if not (Open77 and Open77.blips and type(Open77.blips.create) == "function") then
        print("[rpcore] native map pin API is unavailable on this client")
        updatePage()
        return
    end

    for _, location in ipairs(incoming) do
        if #locations >= MAX_LOCATIONS then break end
        if type(location) == "table" and type(location.id) == "string"
            and type(location.label) == "string" and #location.label > 0 and #location.label <= 64
            and validPosition(location.position) then
            local item = {
                id = location.id,
                label = location.label,
                description = type(location.description) == "string" and location.description or "",
                position = { x = tonumber(location.position.x), y = tonumber(location.position.y), z = tonumber(location.position.z) },
            }
            local id, reason = Open77.blips.create({
                position = item.position,
                sprite = type(location.sprite) == "string" and location.sprite or "objective",
                title = item.label,
                label = item.label,
                description = item.description,
                routable = true,
            })
            if id then
                owned[item.id] = id
                locations[#locations + 1] = item
            else
                print("[rpcore] map pin refused for " .. item.id .. ": " .. tostring(reason))
            end
        end
    end
    updatePage()
end

local function registerMapTab()
    if not (Open77 and Open77.map and type(Open77.map.addTab) == "function") then
        print("[rpcore] native map tabs unavailable; persistent locations remain on the native map as pins")
        return
    end
    local tab, pageOrReason = Open77.map.addTab({
        id = "rpcore-locations",
        label = "Locations",
        url = "web/map/index.html",
        order = 20,
    })
    if not tab then
        print("[rpcore] Locations map tab unavailable: " .. tostring(pageOrReason))
        return
    end
    mapTab, mapPage = tab, pageOrReason
    mapPage:on("rpcore:map:refresh", function()
        TriggerServerEvent(RPCore.Net.MAP_REQUEST)
        updatePage()
    end)
    mapPage:on("rpcore:map:track", function(payload)
        if type(payload) ~= "table" or type(payload.id) ~= "string" then return end
        local id = owned[payload.id]
        if id and Open77.blips and type(Open77.blips.track) == "function" then
            local ok, reason = Open77.blips.track(id)
            if not ok then print("[rpcore] could not route to map location: " .. tostring(reason)) end
        end
    end)
    mapPage:on("rpcore:map:create", function(payload)
        if not editorAllowed or type(payload) ~= "table" then return end
        TriggerServerEvent(RPCore.Net.MAP_CREATE, {
            id = tostring(payload.id or ""),
            label = tostring(payload.label or ""),
            sprite = tostring(payload.sprite or "objective"),
        })
    end)
    AddEventHandler("open77:map:tabEntered", function(event)
        if event.id == mapTab then
            TriggerServerEvent(RPCore.Net.MAP_REQUEST)
            updatePage()
        end
    end)
    AddEventHandler("open77:map:tabRemoved", function(event)
        if event.id == mapTab then
            print("[rpcore] Locations tab removed: " .. tostring(event.reason or "unknown_reason"))
            mapPage, mapTab = nil, nil
        end
    end)
    mapPage:send("rpcore:map:locations", { locations = locations, error = mapError, editorAllowed = editorAllowed })
end

RegisterCommand("rpcore.map", function()
    if not mapTab then registerMapTab() end
    if Open77 and Open77.map and type(Open77.map.open) == "function" then
        local requestId, reason = Open77.map.open()
        if not requestId then
            selectLocationsAfterOpen = false
            print("[rpcore] could not open native map: " .. tostring(reason))
            return
        end
        selectLocationsAfterOpen = mapTab ~= nil
        if not selectLocationsAfterOpen then
            print("[rpcore] native map opened, but RPCore Locations tab is unavailable; check map.control permission and client support")
        end
    else
        print("[rpcore] native map screen API is unavailable on this client")
    end
end, false, { help = "Open the native map and RPCore saved locations" })

AddEventHandler("open77:map:opened", function()
    if not selectLocationsAfterOpen then return end
    selectLocationsAfterOpen = false
    local selected, reason = Open77.map.selectTab(mapTab)
    if not selected then print("[rpcore] could not select Locations tab: " .. tostring(reason)) end
end)

AddEventHandler("open77:map:requestFailed", function(event)
    if not selectLocationsAfterOpen then return end
    selectLocationsAfterOpen = false
    print("[rpcore] native map open failed: " .. tostring(type(event) == "table" and event.reason or event))
end)

RegisterNetEvent(RPCore.Net.MAP_STATE, applyLocations)
RegisterNetEvent(RPCore.Net.MAP_CREATE_RESULT, function(result)
    if mapPage and type(result) == "table" then mapPage:send("rpcore:map:create:result", result) end
end)

AddEventHandler("onClientResourceStart", function(name)
    if name ~= GetCurrentResourceName() then return end
    if Open77 and Open77.hud and type(Open77.hud.setVisible) == "function" then
        local accepted, effective = Open77.hud.setVisible("minimap", true)
        if not accepted or not effective then
            print("[rpcore] native minimap is not visible; check HUD claims and ui.vanilla.hud permission")
        end
    end
    registerMapTab()
    CreateThread(function()
        Wait(500)
        TriggerServerEvent(RPCore.Net.MAP_REQUEST)
    end)
end)

AddEventHandler("onClientResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    clearOwned()
    if mapTab and Open77 and Open77.map and type(Open77.map.removeTab) == "function" then
        Open77.map.removeTab(mapTab)
    end
    mapPage, mapTab = nil, nil
end)
