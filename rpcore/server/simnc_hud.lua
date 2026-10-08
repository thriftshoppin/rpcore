-- RPCore's migrated SIMNC damage hook.
-- Pokes the client the instant real damage lands, so the health ring moves
-- now instead of on the next poll.

local function poke(playerId)
    local id = tonumber(playerId) or 0
    if id > 0 then TriggerClientEvent("simnc:stats:poke", id) end
end

AddEventHandler("open77:playerDamaged", function(victimId) poke(victimId) end)
AddEventHandler("open77:playerDied", function(playerId) poke(playerId) end)
