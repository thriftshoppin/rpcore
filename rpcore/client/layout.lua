-- Per-player layout editor for RPCore's independent HUD surfaces.
RPCore = RPCore or {}
RPCore.Layout = RPCore.Layout or {}

local Layout = RPCore.Layout
local KEY = "rpcore:layout:v1"
local SCALE_REVISION = 2
local surfaces = {}
local positions = {}
local enabled = false
local focused = nil
local persist

local function load()
    local raw = Open77.kvp.get(KEY)
    if type(raw) ~= "string" or raw == "" then return end
    local decoded = Open77.json.decode(raw)
    if type(decoded) ~= "table" then return end
    local revision = tonumber(decoded.scaleRevision) or 0
    if revision < SCALE_REVISION then
        local vitals = type(decoded.vitals) == "table" and decoded.vitals or nil
        local panel = vitals and type(vitals.vitals) == "table" and vitals.vitals or nil
        if panel and tonumber(panel.scale) then
            panel.scale = math.max(0.35, math.min(1, tonumber(panel.scale) * 0.58))
        end
        decoded.scaleRevision = SCALE_REVISION
        positions = decoded
        persist()
        return
    end
    positions = decoded
end

persist = function()
    local encoded = Open77.json.encode(positions)
    if type(encoded) == "string" then
        local ok, reason = Open77.kvp.set(KEY, encoded)
        if not ok then print("[rpcore] could not save HUD layout: " .. tostring(reason)) end
    end
end

local function publish(surface)
    if not surface or not surface.page then return end
    surface.page:send("rpcore:layout:state", {
        enabled = enabled,
        focused = focused == surface.id,
        positions = positions[surface.id] or {},
        surfaces = { "vitals", "activities", "weapon" },
    })
end

local function publishAll()
    for _, surface in pairs(surfaces) do publish(surface) end
end

local function focus(id)
    local target = surfaces[id]
    if not enabled or not target or not target.page then return false end
    if focused and surfaces[focused] and surfaces[focused].page then
        surfaces[focused].page:setFocus(false, false)
    end
    focused = id
    local ok = target.page:setFocus(false, true)
    publishAll()
    return ok ~= false
end

local function close()
    enabled = false
    if focused and surfaces[focused] and surfaces[focused].page then
        surfaces[focused].page:setFocus(false, false)
    end
    focused = nil
    publishAll()
end

function Layout.RegisterSurface(id, page, elementIds)
    local allowed = {}
    for _, elementId in ipairs(elementIds or {}) do allowed[elementId] = true end
    local entry = { id = id, page = page, allowed = allowed }
    surfaces[id] = entry
    page:on("rpcore:layout:save", function(payload)
        if type(payload) ~= "table" or not entry.allowed[tostring(payload.element or "")] then return end
        local x, y = tonumber(payload.x), tonumber(payload.y)
        if not x or not y or x ~= x or y ~= y then return end
        x, y = math.max(0, math.min(1, x)), math.max(0, math.min(1, y))
        positions[id] = positions[id] or {}
        local previous = positions[id][payload.element] or {}
        local scale = tonumber(payload.scale) or tonumber(previous.scale) or 0.45
        if scale ~= scale then scale = 0.45 end
        scale = math.max(0.35, math.min(1, scale))
        positions[id][payload.element] = { x = x, y = y, scale = scale }
        persist()
        publishAll()
    end)
    page:on("rpcore:layout:select", function(payload)
        if type(payload) == "table" then focus(tostring(payload.surface or "")) end
    end)
    page:on("rpcore:layout:close", close)
    page:on("rpcore:layout:open", function()
        if RPCore.CloseSettings then RPCore.CloseSettings() end
        Layout.Toggle()
    end)
    page:on("rpcore:layout:ready", function() publish(entry) end)
    page:on("rpcore:layout:reset", function(payload)
        local elementId = type(payload) == "table" and tostring(payload.element or "") or ""
        if elementId ~= "" and not entry.allowed[elementId] then return end
        if elementId == "" then positions[id] = nil
        elseif positions[id] then positions[id][elementId] = nil end
        persist()
        publishAll()
    end)
    publish(entry)
    if enabled and not focused and id == "vitals" then focus(id) end
end

function Layout.Toggle()
    if enabled then close(); return false end
    enabled = true
    publishAll()
    focus("vitals")
    return true
end

function Layout.Close()
    if enabled then close() end
end

RegisterCommand("rpcore.layout", function() Layout.Toggle() end, false)

AddEventHandler("onClientResourceStart", function(name)
    if name == GetCurrentResourceName() then load() end
end)

AddEventHandler("open77:menuStateChanged", function(open)
    if open == true or tostring(open) == "1" or tostring(open) == "true" then Layout.Close() end
end)

AddEventHandler("onClientResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    if focused and surfaces[focused] and surfaces[focused].page then
        surfaces[focused].page:setFocus(false, false)
    end
end)
