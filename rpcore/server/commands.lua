--- Developer / admin commands. All RESTRICTED: the platform checks the ACL right
-- `command.<name>` (see acl.jsonc) before the handler runs; we add no second gate.
--   /rpcore.demo [player]   start the demonstration activity (default: yourself)
--   /rpcore.status          activity diagnostics, to the caller / console only
--   /rpcore.cancel [player] cancel a player's current activity
local Config = RPCore.Config

--- Caller feedback uses the platform's own command-result event (the convention
-- open77_elevators / open77_vehicles use) plus the server log.
local function reply(source, text, success, raw)
    RPCore.Log.info(text)
    source = tonumber(source)
    if source and source > 0 then
        TriggerClientEvent("open77:command:result", source, raw or "", success ~= false, text)
    end
end

local function adminCommand(name, handler)
    return function(source, args, raw)
        source = tonumber(source) or 0
        RPCore.Async("RPCore admin authorization: " .. name, function()
            if source > 0 then
                if not (RPCore.EventCore and RPCore.EventCore.IsAdmin) then
                    return reply(source, "RPCore admin command unavailable: EventCore is not connected.", false, raw)
                end
                local allowed, reason = RPCore.EventCore.IsAdmin(source)
                if allowed ~= true then
                    return reply(source, "RPCore admin access denied: " .. tostring(reason or "global_admin_required"), false, raw)
                end
            end
            handler(source, args or {}, raw)
        end)
    end
end

local function targetOf(source, args)
    local t = tonumber(args and args[1])
    if t then return t end
    source = tonumber(source)
    if source and source > 0 then return source end
    return nil
end

function RPCore.StartDemo(player)
    if not Config.demo.enabled then return nil, "demo_disabled" end
    if RPCore.Instances.CurrentFor(player) then return nil, "already_in_activity" end
    local inst, why = RPCore.Instances.Create(RPCore.DEMO_ID, { player })
    if not inst then return nil, why end
    local ok = RPCore.Instances.Offer(inst)
    if not ok then return nil, "offer_failed" end
    return inst
end

RegisterCommand(Config.demo.command, adminCommand(Config.demo.command, function(source, args)
    local player = targetOf(source, args)
    if not player then return reply(source, "usage: " .. Config.demo.command .. " <player id>") end
    local inst, why = RPCore.StartDemo(player)
    if inst then reply(source, ("RPCore demo offered to player %d (%s)"):format(player, inst.id))
    else reply(source, "RPCore demo not started: " .. tostring(why)) end
end), true)

RegisterCommand("rpcore.status", adminCommand("rpcore.status", function(source)
    local rows = RPCore.Instances.Diagnostics()
    reply(source, ("RPCore %s: %d definition(s), %d instance(s)")
        :format(RPCore.VERSION, #RPCore.Definitions.List(), #rows))
    local eventCore = RPCore.EventCore and RPCore.EventCore.Status()
    if eventCore then
        reply(source, ("EventCore: %s%s | API %s | %d provider(s)")
            :format(eventCore.connected and "connected" or "unavailable",
                eventCore.version and (" v" .. eventCore.version) or "",
                tostring(eventCore.apiVersion or "unknown"), #eventCore.services))
    end
    for _, row in ipairs(rows) do reply(source, "  " .. row) end
end), true)

RegisterCommand("rpcore.cancel", adminCommand("rpcore.cancel", function(source, args)
    local player = targetOf(source, args)
    local inst = player and RPCore.Instances.CurrentFor(player)
    if not inst then return reply(source, "RPCore: nothing to cancel") end
    RPCore.Instances.Cancel(inst, "cancelled_by_admin")
    reply(source, "RPCore: cancelled " .. inst.id)
end), true)

RegisterCommand("rpcore.map.add", adminCommand("rpcore.map.add", function(source, args, raw)
    local id = type(args[1]) == "string" and args[1] or ""
    local label = table.concat(args, " ", 2)
    if source < 1 or id == "" or label == "" then
        return reply(source, "usage: /rpcore.map.add <id> <label...> (saves your current position)", false, raw)
    end
    local context, contextError = RPCore.EventCore.GetPlayerContext(source)
    if type(context) ~= "table" or type(context.position) ~= "table" then
        return reply(source, "RPCore map location not saved: " .. tostring(contextError or "player_position_unavailable"), false, raw)
    end
    local ok, savedId, outcome = RPCore.Map.AddLocation(id, label, context.position)
    if not ok then return reply(source, "RPCore map location not saved: " .. tostring(savedId), false, raw) end
    reply(source, ("RPCore map location %s: %s (%s)"):format(outcome, label, savedId), true, raw)
end), true)

RegisterCommand("rpcore.map.remove", adminCommand("rpcore.map.remove", function(source, args, raw)
    local id = args[1]
    if type(id) ~= "string" or id == "" then
        return reply(source, "usage: /rpcore.map.remove <id>", false, raw)
    end
    local ok, reason = RPCore.Map.RemoveLocation(id)
    if not ok then return reply(source, "RPCore map location not removed: " .. tostring(reason), false, raw) end
    reply(source, "RPCore map location removed: " .. id, true, raw)
end), true)

RegisterCommand("rpcore.map.list", adminCommand("rpcore.map.list", function(source, _args, raw)
    local locations, reason = RPCore.Map.ListLocations()
    if not locations then return reply(source, "RPCore map locations unavailable: " .. tostring(reason), false, raw) end
    reply(source, ("RPCore map: %d saved location(s)"):format(#locations), true, raw)
    for _, location in ipairs(locations) do
        reply(source, ("  %s — %s (%.1f, %.1f, %.1f)"):format(location.id, location.label,
            location.position.x, location.position.y, location.position.z), true, raw)
    end
end), true)
