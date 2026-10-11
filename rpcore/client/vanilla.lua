-- RPCore vanilla HUD manager.
--
-- Owns RPCore's claims on the game's native HUD widgets (through Open77.hud) and
-- applies server-driven element overrides published over EventCore's state feed
-- (channel "rpcore.hud.control"). Native widgets get visibility only; the game
-- owns their screen position and Open77 exposes no API to move them. RPCore
-- panels and gauges also get opacity and placement through the page layer
-- (client/layout.lua -> web/layout.js).
--
-- Open77.hud.setVisible(name, false) places RPCore's hide claim on a widget;
-- setVisible(name, true) releases only RPCore's own claim (it never fights
-- another resource's claim). That is the contract this file relies on.
RPCore = RPCore or {}
RPCore.Vanilla = RPCore.Vanilla or {}

local Vanilla = RPCore.Vanilla
local CHANNEL, SCHEMA_VERSION = "rpcore.hud.control", 1

local applied = {}          -- [elementId] = what RPCore last asked for: true | false | nil (no claim)
local lastEpoch, lastSequence = nil, 0
local currentElements = {}  -- last accepted override snapshot

local function say(text)
    print("[rpcore] " .. text)
    TriggerEvent("chat:addMessage", { type = "system", author = "RPCore", text = text })
end

local function hudApi()
    local hud = Open77 and Open77.hud
    if hud and type(hud.setVisible) == "function" then return hud end
    return nil
end

--- Ask Open77 for a native widget's visibility. true = release RPCore's claim.
local function request(component, visible)
    local hud = hudApi()
    if not hud then return false, "hud_visibility_api_unavailable" end
    local called, accepted, visibleOrReason = pcall(hud.setVisible, component, visible)
    if not called then return false, tostring(accepted) end
    if accepted ~= true then return false, tostring(visibleOrReason or "visibility_request_refused") end
    return true
end

--- Move one native element to `want` (true | false | nil = hold no claim).
local function setNative(def, want)
    if applied[def.id] == want then return true end
    local visible = want
    if visible == nil then visible = true end -- releasing the claim
    local ok, reason = request(def.component, visible)
    if ok then applied[def.id] = want end
    return ok, reason
end

--- Apply Config.vanilla defaults (e.g. hide the widgets an RPCore element replaces).
function Vanilla.ApplyDefaults()
    for _, def in ipairs(RPCore.Elements.list) do
        if def.kind == "native" and def.default ~= nil then
            local ok, reason = setNative(def, def.default)
            if not ok then
                print(("[rpcore] could not set native %s HUD: %s"):format(def.component, tostring(reason)))
            end
        end
    end
end

local function applySnapshot(elements)
    local accepted = {}
    if type(elements) == "table" then
        for id, entry in pairs(elements) do
            -- Ignore ids this build does not know: the server may be newer.
            if type(id) == "string" and RPCore.Elements.Get(id) and type(entry) == "table" then
                accepted[id] = entry
            end
        end
    end
    currentElements = accepted

    for _, def in ipairs(RPCore.Elements.list) do
        if def.kind == "native" then
            local entry = accepted[def.id]
            local want = def.default
            if entry and type(entry.visible) == "boolean" then want = entry.visible end
            local ok, reason = setNative(def, want)
            if not ok then
                print(("[rpcore] native %s HUD request failed: %s"):format(def.component, tostring(reason)))
            end
        end
    end

    -- Panels and gauges live in the WebUI pages; hand them the same snapshot.
    if RPCore.Layout and RPCore.Layout.SetControl then RPCore.Layout.SetControl(accepted) end
end

--- Called by client/hud.lua's single eventcore:net:state:update handler.
function Vanilla.OnFeed(packet)
    if type(packet) ~= "table" or packet.protocolVersion ~= 1
        or packet.channel ~= CHANNEL or packet.schemaVersion ~= SCHEMA_VERSION
        or packet.publisher ~= "rpcore" or type(packet.epoch) ~= "string"
        or type(packet.sequence) ~= "number" or packet.sequence < 1
        or packet.sequence % 1 ~= 0 or type(packet.state) ~= "table" then return end
    if packet.epoch == lastEpoch and packet.sequence <= lastSequence then return end
    lastEpoch, lastSequence = packet.epoch, packet.sequence
    applySnapshot(packet.visible and packet.state.elements or nil)
end

--- Snapshot of what RPCore currently asks for (diagnostics / other client code).
function Vanilla.Status()
    local out = {}
    for _, def in ipairs(RPCore.Elements.list) do
        out[#out + 1] = { id = def.id, kind = def.kind, claim = applied[def.id], override = currentElements[def.id] }
    end
    return out
end

-- ── diagnostics ─────────────────────────────────────────────────────────────

RegisterCommand("rpcore.vanilla", function()
    local hud = Open77 and Open77.hud
    for _, def in ipairs(RPCore.Elements.list) do
        if def.kind == "native" then
            local effective = "unknown"
            if hud and type(hud.isVisible) == "function" then
                local ok, visible, reason = pcall(hud.isVisible, def.component)
                effective = ok and tostring(visible == nil and reason or visible) or "error"
            end
            local claim = applied[def.id]
            say(("%s  claim=%s  shown=%s%s"):format(def.id,
                claim == nil and "none" or (claim and "show" or "hide"), effective,
                def.mirror and ("  (replaced by " .. def.mirror .. ")") or ""))
        end
    end
    local overrides = 0
    for _ in pairs(currentElements) do overrides = overrides + 1 end
    say(("%d element override(s) active. Catalog: %d element(s)."):format(overrides, #RPCore.Elements.list))
end, false, { help = "List native HUD claims and active RPCore element overrides" })

-- Non-destructive: only READS visibility, so it is safe to try any name.
RegisterCommand("rpcore.vanilla.probe", function(_, args)
    local hud = Open77 and Open77.hud
    if not (hud and type(hud.isVisible) == "function") then
        say("Open77.hud.isVisible is unavailable on this build.")
        return
    end
    if type(args) ~= "table" or #args == 0 then
        say("Usage: /rpcore.vanilla.probe <component> [component ...]")
        return
    end
    -- Open77 documents no list of component names and no unknown-name contract,
    -- so report exactly what it returned rather than guessing.
    for _, name in ipairs(args) do
        name = tostring(name)
        local ok, first, second = pcall(hud.isVisible, name)
        say(("probe '%s': call %s, returned %s, %s"):format(
            name, ok and "succeeded" or "raised an error", tostring(first), tostring(second)))
    end
end, false, {
    help = "Check which native HUD component names this Open77 build accepts",
    parameters = { { name = "component", optional = false, help = "Component name, e.g. minimap" } },
})
