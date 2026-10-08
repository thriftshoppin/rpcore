--- Client -> server events. Net events carry NO authorisation, so every handler
-- here is self-scoped (acts only on the sender's own activity), state-checked,
-- whitelisted and rate-limited. Anything privileged is a restricted command.
local Config = RPCore.Config
local lastAt = {}

local function allowed(player)
    player = tonumber(player)
    if not player or player <= 0 then return nil end
    local now = RPCore.Now()
    if lastAt[player] and now - lastAt[player] < Config.limits.netIntervalMs then return nil end
    lastAt[player] = now
    return player
end

RegisterNetEvent(RPCore.Net.RESPOND, function(activityId, response)
    local player = allowed(source)
    if not player or type(activityId) ~= "string" then return end
    local inst = RPCore.Instances.Get(activityId)
    if not inst or inst.status ~= RPCore.State.OFFERED or not inst.participants[player] then return end
    if response == "accept" then RPCore.Instances.Accept(inst, player)
    elseif response == "decline" then RPCore.Instances.Decline(inst, player) end
end)

RegisterNetEvent(RPCore.Net.ACTION, function(event)
    local player = allowed(source)
    if not player or type(event) ~= "string" or not Config.clientEvents[event] then return end
    RPCore.Events.Emit(player, event, { source = "client" })
end)

RegisterNetEvent(RPCore.Net.JOURNAL, function()
    local player = allowed(source)
    if player then RPCore.Presentation.SendJournal(player) end
end)

AddEventHandler("playerDropped", function()
    local player = tonumber(source)
    if player then
        lastAt[player] = nil
        RPCore.Instances.PlayerLeft(player)
    end
end)
