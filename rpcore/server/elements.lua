--- Server-owned HUD element control.
--
-- EventCore (or another allowed resource) calls the exports below to show,
-- hide, fade or move any element in shared/elements.lua for a player. RPCore
-- validates the request, keeps the per-player override table in memory, and
-- publishes the WHOLE table as a versioned snapshot over EventCore's client
-- state feed (channel "rpcore.hud.control"). Snapshots are idempotent, so a
-- reconnecting client converges without replaying individual commands.
--
--   exports.rpcore:GetHudElements()                       -> catalog   (open)
--   exports.rpcore:GetHudElementState(player)             -> overrides (open)
--   exports.rpcore:SetHudElement(player, id, patch)       -> true | nil, reason
--        patch = { visible = bool, opacity = 0..1, placement = { x, y, scale } }
--   exports.rpcore:ResetHudElement(player, id)            -> true | nil, reason
--   exports.rpcore:ResetHudElements(player)               -> true | nil, reason
--
-- The writes obey Config.exports.allowedCallers. Overrides live in memory only:
-- the owning provider re-sends them after a restart, exactly like survival vitals.
RPCore = RPCore or {}
RPCore.Hud = RPCore.Hud or {}

local CHANNEL, SCHEMA_VERSION = "rpcore.hud.control", 1
local MAX_PLAYERS_PER_FLUSH = 64

local byPlayer = {}   -- [playerId] = { [elementId] = { visible, opacity, placement } }
local dirty = {}      -- [playerId] = true, awaiting publish
local flushing = false
local lastError = nil

local function playerId(value)
    local id = tonumber(value)
    if not id or id < 1 or id % 1 ~= 0 then return nil end
    return id
end

--- Plain-data copy of one player's overrides (safe to publish or return).
local function snapshot(id)
    local out = {}
    for elementId, entry in pairs(byPlayer[id] or {}) do
        local copy = { visible = entry.visible, opacity = entry.opacity }
        if entry.placement then
            copy.placement = { x = entry.placement.x, y = entry.placement.y, scale = entry.placement.scale }
        end
        out[elementId] = copy
    end
    return out
end

local function publish(id)
    if not RPCore.EventCore then return false, "eventcore_unavailable" end
    local ok, reason = RPCore.EventCore.PublishClientState(id, CHANNEL, SCHEMA_VERSION, { elements = snapshot(id) })
    if ok ~= true then
        local message = tostring(reason or "publish_failed")
        if message ~= lastError then RPCore.Log.warn("HUD control feed unavailable: " .. message) end
        lastError = message
        return false, message
    end
    lastError = nil
    return true
end

--- Exports must not yield, so state changes are applied immediately and the
--- (yielding) EventCore publish is coalesced onto one host-managed thread.
local function markDirty(id)
    dirty[id] = true
    if flushing then return end
    flushing = true
    RPCore.Async("HUD control publish", function()
        while next(dirty) ~= nil do
            local batch, count = {}, 0
            for pid in pairs(dirty) do
                batch[#batch + 1] = pid
                dirty[pid] = nil
                count = count + 1
                if count >= MAX_PLAYERS_PER_FLUSH then break end
            end
            for _, pid in ipairs(batch) do
                local ok, err = pcall(publish, pid)
                if not ok then RPCore.Log.warn("HUD control publish failed: " .. tostring(err)) end
            end
        end
        flushing = false
    end)
end

function RPCore.Hud.SetElement(rawId, elementId, patch)
    local id = playerId(rawId)
    if not id then return nil, "invalid_player_id" end
    if type(elementId) ~= "string" then return nil, "unknown_element" end
    local clean, reason = RPCore.Elements.Sanitize(elementId, patch)
    if not clean then return nil, reason end
    local entries = byPlayer[id] or {}
    local entry = entries[elementId] or {}
    for key, value in pairs(clean) do entry[key] = value end
    entries[elementId] = entry
    byPlayer[id] = entries
    markDirty(id)
    return true
end

function RPCore.Hud.ResetElement(rawId, elementId)
    local id = playerId(rawId)
    if not id then return nil, "invalid_player_id" end
    if type(elementId) ~= "string" or not RPCore.Elements.Get(elementId) then return nil, "unknown_element" end
    if byPlayer[id] then
        byPlayer[id][elementId] = nil
        if next(byPlayer[id]) == nil then byPlayer[id] = nil end
    end
    markDirty(id)
    return true
end

function RPCore.Hud.ResetElements(rawId)
    local id = playerId(rawId)
    if not id then return nil, "invalid_player_id" end
    byPlayer[id] = nil
    markDirty(id)
    return true
end

exports("GetHudElements", function() return RPCore.Elements.Catalog() end)

exports("GetHudElementState", function(rawId)
    local id = playerId(rawId)
    if not id then return nil, "invalid_player_id" end
    return snapshot(id)
end)

exports("SetHudElement", function(player, elementId, patch)
    local caller, why = RPCore.GuardExport()
    if not caller then return nil, why end
    return RPCore.Hud.SetElement(player, elementId, patch)
end)

exports("ResetHudElement", function(player, elementId)
    local caller, why = RPCore.GuardExport()
    if not caller then return nil, why end
    return RPCore.Hud.ResetElement(player, elementId)
end)

exports("ResetHudElements", function(player)
    local caller, why = RPCore.GuardExport()
    if not caller then return nil, why end
    return RPCore.Hud.ResetElements(player)
end)

AddEventHandler("playerDropped", function()
    local id = playerId(source)
    if id then byPlayer[id] = nil; dirty[id] = nil end
end)
