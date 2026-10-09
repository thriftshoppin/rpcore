-- RPCore's location pins use the game's own map projection and native blip
-- renderer. A Locations tab is added to the native City Map; it lists saved
-- places and can route to one without trying to redraw the game's map texture.
RPCore = RPCore or {}
RPCore.Map = RPCore.Map or {}

local owned = {}
local locations = {}
local mapError
local editorAllowed = false
local mapPage
local mapTab
local mapRequestPending = false
local mapOpenedByRpcore = false
local MAX_LOCATIONS = 64

local function releaseMinimapHideClaim()
    local hud = Open77 and Open77.hud
    if not (hud and type(hud.setVisible) == "function") then
        return false, "hud_visibility_api_unavailable"
    end

    -- `true` releases only RPCore's own hide claim. It deliberately does not
    -- fight another resource that still owns a hide claim.
    local called, accepted, visibleOrReason = pcall(hud.setVisible, "minimap", true)
    if not called then return false, tostring(accepted) end
    if accepted ~= true then return false, tostring(visibleOrReason or "visibility_request_refused") end
    return true, visibleOrReason == true
end

local function reportMinimapStatus()
    local released, visibleOrReason = releaseMinimapHideClaim()
    if not released then
        print("[rpcore] native minimap visibility request failed: " .. tostring(visibleOrReason))
        return
    end
    if visibleOrReason then
        print("[rpcore] native game minimap is enabled; native map pins use the same game renderer")
    else
        print("[rpcore] native minimap is still hidden by another resource's HUD claim")
    end
end

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

local function mapIsOpen()
    if not (Open77 and Open77.map and type(Open77.map.isOpen) == "function") then return false end
    local called, ok, opened = pcall(Open77.map.isOpen)
    -- Open77 versions that return (ok, isOpen, reason) and versions that
    -- return just isOpen are both supported.
    if not called then return false end
    if type(opened) == "boolean" then return ok == true and opened end
    return ok == true
end

local function selectLocations()
    if not mapTab or not (Open77 and Open77.map and type(Open77.map.selectTab) == "function") then
        print("[rpcore] native map is open, but the Locations tab is unavailable; check map.control permission")
        return
    end
    local selected, reason = Open77.map.selectTab(mapTab)
    if not selected then print("[rpcore] could not select Locations tab: " .. tostring(reason)) end
end

local function openMap()
    if not mapTab then registerMapTab() end
    if not (Open77 and Open77.map and type(Open77.map.open) == "function") then
        print("[rpcore] native map screen API is unavailable on this client")
        return false
    end
    if mapIsOpen() then
        selectLocations()
        TriggerServerEvent(RPCore.Net.MAP_REQUEST)
        return true
    end
    local requestId, reason = Open77.map.open()
    if not requestId then
        mapRequestPending = false
        print("[rpcore] could not open native map: " .. tostring(reason))
        return false
    end
    mapRequestPending = true
    return true
end

function RPCore.Map.Toggle()
    if mapIsOpen() then
        if mapOpenedByRpcore and Open77.map and type(Open77.map.close) == "function" then
            local closed, reason = Open77.map.close()
            if not closed then print("[rpcore] could not close native map: " .. tostring(reason)) end
            return closed == true
        end
        selectLocations()
        return true
    end
    mapOpenedByRpcore = false
    return openMap()
end

RegisterCommand("rpcore.map", function() RPCore.Map.Toggle() end, false,
    { help = "Open the native map and RPCore saved locations" })
RegisterCommand("rpcore.map.minimap", reportMinimapStatus, false,
    { help = "Release RPCore's minimap hide claim and report native minimap visibility" })

AddEventHandler("open77:map:opened", function()
    if not mapRequestPending then return end
    mapRequestPending = false
    mapOpenedByRpcore = true
    selectLocations()
end)

AddEventHandler("open77:map:requestFailed", function(event)
    if not mapRequestPending then return end
    mapRequestPending = false
    print("[rpcore] native map open failed: " .. tostring(type(event) == "table" and event.reason or event))
end)

AddEventHandler("open77:map:closed", function()
    mapRequestPending = false
    mapOpenedByRpcore = false
end)

RegisterNetEvent(RPCore.Net.MAP_STATE, applyLocations)
RegisterNetEvent(RPCore.Net.MAP_CREATE_RESULT, function(result)
    if mapPage and type(result) == "table" then mapPage:send("rpcore:map:create:result", result) end
end)

AddEventHandler("onClientResourceStart", function(name)
    if name ~= GetCurrentResourceName() then return end
    -- Open77 loads alongside resources; defer the first visibility call so the
    -- native HUD bridge is ready. Expose the same check as a command for test
    -- sessions where another resource changes its claim later.
    CreateThread(function()
        Wait(1000)
        reportMinimapStatus()
    end)
    registerMapTab()
    -- Open77 owns the native map session; using B here opens it when closed
    -- and lets the native map own B (close/back) after it is open.
    CreateThread(function()
        local wasDown = false
        while true do
            Wait(25)
            local input = Open77 and Open77.input
            local checked, isDown = false, false
            if input and type(input.isDown) == "function" then
                checked, isDown = pcall(input.isDown, "padB")
            end
            local down = checked and isDown == true
            local captured = false
            if input and type(input.isCaptured) == "function" then
                local capturedOk, capturedValue = pcall(input.isCaptured)
                captured = not capturedOk or capturedValue == true
            end
            if down and not wasDown and not captured and not mapIsOpen() then
                openMap()
            end
            wasDown = down == true
        end
    end)
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
    mapRequestPending = false
    mapOpenedByRpcore = false
end)
