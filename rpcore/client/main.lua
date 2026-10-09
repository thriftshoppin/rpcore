--- RPCore client: owns the HUD page and relays server presentation messages to it.
-- No activity logic lives here. The page is a pure renderer of what the server
-- sends; the client only (a) forwards messages, (b) keeps the page's first frame
-- correct, (c) steps the HUD aside while a game menu covers the screen.
RPCore = RPCore or {}
local Config = RPCore.Config

local page = nil
local ready = false
local queue = {}             -- messages that arrived before the page said it was ready
local lastTracker = nil      -- re-sent after a page (re)load so the HUD is never blank
local offerOpen = nil        -- activity id of the offer currently on screen (input.lua reads it)
local settingsOpen = false

-- Platform menu sources the HUD steps aside for (same signal other HUDs use).
local HIDE_FOR = { appearance = true, creator = true, vanilla = true, photoMode = true }

local function post(channel, payload)
    if not page then return end
    local ok, reason = page:send(channel, payload or {})
    if ok == false then print("[rpcore] page send failed: " .. tostring(reason)) end
end

local function deliver(msg)
    if msg.type == "offer" then offerOpen = msg.activity.id
    elseif msg.type == "offerClosed" then if offerOpen == msg.id then offerOpen = nil end
    elseif msg.type == "tracker" then lastTracker = msg
    elseif msg.type == "complete" or msg.type == "failed" or msg.type == "clear" then lastTracker = nil end
    if ready then post("rpcore:ui", msg) else queue[#queue + 1] = msg end
end

function RPCore.OfferOpen() return offerOpen end

local function setSettings(open)
    settingsOpen = open == true
    if not page then return end
    post("rpcore:settings", { open = settingsOpen })
    if type(page.setFocus) == "function" then page:setFocus(settingsOpen, settingsOpen) end
end

function RPCore.ToggleSettings() setSettings(not settingsOpen) end
function RPCore.CloseSettings() if settingsOpen then setSettings(false) end end

local function createPage()
    -- The surface stays up for the whole session and the page hides its own
    -- content: creating a surface hidden and toggling it is the path other HUDs
    -- here document as losing the paint race.
    local surface, err = Open77.webui.create({
        entry = "web/index.html", layer = "hud", zIndex = 560,
        transparent = true, visible = true,
    })
    if not surface then print("[rpcore] failed to create HUD page: " .. tostring(err)) return end
    page = surface
    if RPCore.Layout then RPCore.Layout.RegisterSurface("activities", page, { "stack", "journal", "controls" }) end
    page:on("rpcore:settings:close", function() RPCore.CloseSettings() end)
    page:on("rpcore:bind:change", function(payload)
        if type(payload) ~= "table" or not RPCore.Client then return end
        local requestedKey = payload.key
        if payload.reset == true then requestedKey = nil end
        local ok, effective = RPCore.Client.Rebind(payload.id, requestedKey)
        post("rpcore:bind:result", { id = payload.id, ok = ok == true, key = effective })
    end)
    page:on("rpcore:journal:close", function()
        RPCore.SetJournalOpen(false)
        post("rpcore:journal", { open = false })
    end)
    page:on("rpcore:ready", function()
        ready = true
        post("rpcore:config", { ui = Config.ui, keys = Config.keys })
        if RPCore.Client and RPCore.Client.PublishKeybinds then RPCore.Client.PublishKeybinds() end
        if lastTracker then post("rpcore:ui", lastTracker) end
        for _, msg in ipairs(queue) do post("rpcore:ui", msg) end
        queue = {}
    end)
end

-- EventCore owns the server-to-client route. Its client listener and this
-- listener run in separate resource VMs, so RPCore consumes the documented
-- wire event directly instead of reaching into EventCore's Lua globals.
RegisterNetEvent("eventcore:net:" .. RPCore.Net.UI, function(msg)
    if type(msg) == "table" and type(msg.type) == "string" then deliver(msg) end
end)

AddEventHandler("open77:menuStateChanged", function(open, _pause, src)
    local isOpen = open == true or tostring(open) == "1" or tostring(open) == "true"
    if isOpen then RPCore.CloseSettings() end
    post("rpcore:visible", { shown = not (isOpen and HIDE_FOR[tostring(src)] == true) })
end)

AddEventHandler("onClientResourceStart", function(name)
    if name ~= GetCurrentResourceName() then return end
    createPage()
end)

--- Used by input.lua to toggle the journal page section.
function RPCore.PagePost(channel, payload) post(channel, payload) end
