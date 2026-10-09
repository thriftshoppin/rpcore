-- Render the server's persistent public locations as resource-owned native
-- map pins. The native minimap/map remains the platform's own interface.
RPCore = RPCore or {}

local owned = {}
local MAX_LOCATIONS = 64

local function validPosition(position)
    if type(position) ~= "table" then return false end
    for _, axis in ipairs({ "x", "y", "z" }) do
        local value = tonumber(position[axis])
        if not value or value ~= value or value == math.huge or value == -math.huge
            or math.abs(value) > 16000 then
            return false
        end
    end
    return true
end

local function clearOwned()
    if not (Open77 and Open77.blips and type(Open77.blips.remove) == "function") then return end
    for _, id in pairs(owned) do Open77.blips.remove(id) end
    owned = {}
end

local function applyLocations(locations)
    if type(locations) ~= "table" then return end
    if not (Open77 and Open77.blips and type(Open77.blips.create) == "function") then
        print("[rpcore] native map pin API is unavailable on this client")
        return
    end
    clearOwned()
    local count = 0
    for _, location in ipairs(locations) do
        if count >= MAX_LOCATIONS then break end
        if type(location) == "table" and type(location.id) == "string"
            and type(location.label) == "string" and #location.label > 0 and #location.label <= 64
            and validPosition(location.position) then
            local options = {
                position = {
                    x = tonumber(location.position.x),
                    y = tonumber(location.position.y),
                    z = tonumber(location.position.z),
                },
                sprite = type(location.sprite) == "string" and location.sprite or "objective",
                title = location.label,
                label = location.label,
                description = type(location.description) == "string" and location.description or "",
                routable = true,
            }
            local id, reason = Open77.blips.create(options)
            if id then
                owned[location.id] = id
                count = count + 1
            else
                print("[rpcore] map pin refused for " .. location.id .. ": " .. tostring(reason))
            end
        end
    end
end

RegisterNetEvent(RPCore.Net.MAP_STATE, applyLocations)

AddEventHandler("onClientResourceStart", function(name)
    if name ~= GetCurrentResourceName() then return end
    if Open77 and Open77.hud and type(Open77.hud.setVisible) == "function" then
        local accepted, effective = Open77.hud.setVisible("minimap", true)
        if not accepted or not effective then
            print("[rpcore] native minimap is not visible; check HUD claims and ui.vanilla.hud permission")
        end
    end
    CreateThread(function()
        Wait(500)
        TriggerServerEvent(RPCore.Net.MAP_REQUEST)
    end)
end)

AddEventHandler("onClientResourceStop", function(name)
    if name == GetCurrentResourceName() then clearOwned() end
end)
