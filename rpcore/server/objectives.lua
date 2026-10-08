--- Objective/event resolution.
-- Game facts enter as events: RPCore.Events.Emit(player, "event.name", data).
-- An activity's CURRENT objective declares what completes it (`completeOn`);
-- this module matches facts to objectives and asks the instance engine to
-- advance. Nothing here (or in the UI) says "if player did X then complete".
RPCore.Events = {}

--- Emit an objective event for a player. Returns how many objectives it advanced.
function RPCore.Events.Emit(player, event, data)
    player = tonumber(player)
    if not player or type(event) ~= "string" then return 0 end
    local inst = RPCore.Instances.CurrentFor(player)
    if not inst or inst.status ~= RPCore.State.ACTIVE then return 0 end
    local def = RPCore.Definitions.Get(inst.definitionId)
    local objective = def and def.objectives[inst.currentIndex]
    if not objective or objective.completeOn.event ~= event then return 0 end
    -- Data match (works for definitions registered through exports): every key in
    -- `where` must equal the same key in the event data.
    local where = objective.completeOn.where
    if type(where) == "table" then
        local facts = type(data) == "table" and data or {}
        for k, v in pairs(where) do if facts[k] ~= v then return 0 end end
    end
    local match = objective.completeOn.match
    if type(match) == "function" then
        local ok, yes = pcall(match, data or {}, inst, player)
        if not ok then RPCore.Log.error(("%s match failed: %s"):format(inst.id, tostring(yes))) return 0 end
        if not yes then return 0 end
    end
    RPCore.Log.debug(("%s objective '%s' resolved by %s"):format(inst.id, objective.id, event))
    return RPCore.Instances.CompleteCurrentObjective(inst) and 1 or 0
end

--- Emit to a player after a delay. Safe against the objective having moved on.
function RPCore.Events.EmitAfter(player, event, ms, inst, index)
    SetTimeout(ms, function()
        if inst and (inst.status ~= RPCore.State.ACTIVE or inst.currentIndex ~= index) then return end
        RPCore.Events.Emit(player, event)
    end)
end
