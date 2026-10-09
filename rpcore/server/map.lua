-- Persistent public map locations. EventCore owns the SQL connection and
-- isolates this collection in RPCore's approved resource namespace.
RPCore = RPCore or {}
RPCore.Map = RPCore.Map or {}

local COLLECTION = "map_locations"
local MAX_LOCATIONS = 64
local MAX_COORDINATE = 16000
local lastSnapshotRequest = {}

local function validPosition(position)
    if type(position) ~= "table" then return false end
    for _, axis in ipairs({ "x", "y", "z" }) do
        local value = tonumber(position[axis])
        if not value or value ~= value or value == math.huge or value == -math.huge
            or math.abs(value) > MAX_COORDINATE then
            return false
        end
    end
    return true
end

local function validId(id)
    return type(id) == "string" and #id >= 1 and #id <= 48
        and id:match("^[a-z0-9][a-z0-9_-]*$") ~= nil
end

local function cleanLocation(id, value)
    if type(value) ~= "table" or not validPosition(value.position)
        or type(value.label) ~= "string" or #value.label < 1 or #value.label > 64 then
        return nil
    end
    local sprite = type(value.sprite) == "string" and value.sprite or "objective"
    if #sprite > 40 or not sprite:match("^[a-z0-9_%-]+$") then sprite = "objective" end
    local description = type(value.description) == "string" and value.description or ""
    if #description > 192 then description = description:sub(1, 192) end
    return {
        id = id,
        label = value.label,
        position = {
            x = tonumber(value.position.x),
            y = tonumber(value.position.y),
            z = tonumber(value.position.z),
        },
        sprite = sprite,
        description = description,
    }
end

local function loadLocations()
    if not (RPCore.EventCore and RPCore.EventCore.Call) then
        return nil, "eventcore_unavailable"
    end
    local rows, reason = RPCore.EventCore.Call("StorageList", COLLECTION, nil, 100)
    if type(rows) ~= "table" then return nil, tostring(reason or "storage_read_failed") end

    local locations = {}
    for _, row in ipairs(rows) do
        if type(row) == "table" and validId(row.key) then
            local location = cleanLocation(row.key, row.value)
            if location then locations[#locations + 1] = location end
        end
    end
    table.sort(locations, function(left, right) return left.id < right.id end)
    return locations
end

local function copyLocations(locations)
    local copy = {}
    for index, location in ipairs(locations) do
        copy[index] = {
            id = location.id,
            label = location.label,
            position = { x = location.position.x, y = location.position.y, z = location.position.z },
            sprite = location.sprite,
            description = location.description,
        }
    end
    return copy
end

local function publish(target)
    local locations, reason = loadLocations()
    if not locations then
        RPCore.Log.warn("map location load failed: " .. tostring(reason))
        return false, reason
    end
    TriggerClientEvent(RPCore.Net.MAP_STATE, target or -1, copyLocations(locations))
    return true, locations
end

function RPCore.Map.ListLocations()
    local locations, reason = loadLocations()
    if not locations then return nil, reason end
    return copyLocations(locations)
end

function RPCore.Map.AddLocation(id, label, position, options)
    id = type(id) == "string" and id:lower() or ""
    label = type(label) == "string" and label:match("^%s*(.-)%s*$") or ""
    options = type(options) == "table" and options or {}
    if not validId(id) then return false, "invalid_location_id" end
    if #label < 1 or #label > 64 then return false, "label_must_be_1_to_64_characters" end
    if not validPosition(position) then return false, "invalid_position" end

    local locations, reason = loadLocations()
    if not locations then return false, reason end
    local existing = false
    for _, location in ipairs(locations) do
        if location.id == id then existing = true; break end
    end
    if not existing and #locations >= MAX_LOCATIONS then return false, "map_location_limit_reached" end

    local sprite = type(options.sprite) == "string" and options.sprite or "objective"
    if #sprite > 40 or not sprite:match("^[a-z0-9_%-]+$") then return false, "invalid_sprite" end
    local description = type(options.description) == "string" and options.description or ""
    if #description > 192 then return false, "description_too_long" end
    local value = {
        label = label,
        position = { x = tonumber(position.x), y = tonumber(position.y), z = tonumber(position.z) },
        sprite = sprite,
        description = description,
    }
    local ok, writeReason = RPCore.EventCore.Call("StoragePut", COLLECTION, id, value)
    if ok ~= true then return false, tostring(writeReason or "storage_write_failed") end
    publish(-1)
    return true, id, existing and "updated" or "created"
end

function RPCore.Map.RemoveLocation(id)
    id = type(id) == "string" and id:lower() or ""
    if not validId(id) then return false, "invalid_location_id" end
    local locations, reason = loadLocations()
    if not locations then return false, reason end
    local found = false
    for _, location in ipairs(locations) do
        if location.id == id then found = true; break end
    end
    if not found then return false, "location_not_found" end
    local removed, deleteReason = RPCore.EventCore.Call("StorageDelete", COLLECTION, id)
    if removed ~= true then return false, tostring(deleteReason or "storage_delete_failed") end
    publish(-1)
    return true
end

RegisterNetEvent(RPCore.Net.MAP_REQUEST, function()
    local player = tonumber(source)
    if not player or player < 1 then return end
    local now = RPCore.Now()
    if lastSnapshotRequest[player] and now - lastSnapshotRequest[player] < 3000 then return end
    lastSnapshotRequest[player] = now
    RPCore.Async("RPCore map snapshot", function()
        -- Storage may still be opening immediately after server startup.
        for attempt = 1, 5 do
            local ok = publish(player)
            if ok then return end
            Wait(1000)
        end
    end)
end)
