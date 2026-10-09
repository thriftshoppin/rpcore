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
