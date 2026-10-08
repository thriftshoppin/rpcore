--- Presentation: turns engine facts into player-facing messages.
-- The ONLY server module that talks to clients about activities. It reads
-- engine state (through RPCore.Bus + read-only snapshots) and never changes it.
-- The client page renders these messages; it holds no activity logic.
--
-- Message shapes ({ type = ... } over RPCore.Net.UI):
--   offer      { activity, timeoutMs }          offerClosed { id, outcome }
--   tracker    { activity }                     objectiveDone { id, index }
--   complete   { activity, reward }             reward { id, status }
--   failed     { activity, outcome, reason }    clear {}
--   journal    { active = {…}, history = {…} }
RPCore.Presentation = {}
local S = RPCore.State

local function send(player, msg) RPCore.EventCore.SendClient(player, msg) end

--- A read-only view of an instance. Plain data: safe to serialise, no internals.
function RPCore.Presentation.Snapshot(inst)
    local objectives = {}
    for i, o in ipairs(inst.objectives) do
        objectives[i] = { title = o.title, status = o.status }
    end
    local current = inst.objectives[inst.currentIndex]
    return {
        id = inst.id, name = inst.name, description = inst.description, status = inst.status,
        index = inst.currentIndex, count = #inst.objectives, objectives = objectives,
        objective = current and { title = current.title, description = current.description } or nil,
        reward = RPCore.Rewards.Describe(inst.reward.spec), rewardStatus = inst.reward.status,
        outcome = inst.result and inst.result.outcome or nil,
    }
end

local function each(inst, fn)
    for _, p in ipairs(inst.participantList) do fn(p) end
end

RPCore.Bus.On("activity.transition", function(inst, _, to, reason)
    local snap = RPCore.Presentation.Snapshot(inst)
    local ui = RPCore.Config.ui
    if to == S.OFFERED then
        local def = RPCore.Definitions.Get(inst.definitionId)
        each(inst, function(p) send(p, { type = "offer", activity = snap, timeoutMs = def and def.offerTimeoutMs or 0 }) end)
    elseif to == S.ACTIVE then
        each(inst, function(p) send(p, { type = "offerClosed", id = inst.id, outcome = "accepted" }) end)
    elseif to == S.DECLINED or to == S.LAPSED then
        each(inst, function(p) send(p, { type = "offerClosed", id = inst.id, outcome = to }) end)
    elseif to == S.COMPLETED then
        each(inst, function(p) send(p, { type = "complete", activity = snap }) end)
        RPCore.Async("reward grant", RPCore.Rewards.Grant, inst)
    elseif to == S.FAILED or to == S.CANCELLED then
        each(inst, function(p) send(p, { type = "failed", activity = snap, outcome = to, reason = reason }) end)
    end
end)

RPCore.Bus.On("objective.activated", function(inst)
    local snap = RPCore.Presentation.Snapshot(inst)
    each(inst, function(p) send(p, { type = "tracker", activity = snap }) end)
end)

RPCore.Bus.On("objective.completed", function(inst, index)
    each(inst, function(p) send(p, { type = "objectiveDone", id = inst.id, index = index }) end)
end)

RPCore.Bus.On("activity.reward", function(inst)
    each(inst, function(p) send(p, { type = "reward", id = inst.id, status = inst.reward.status }) end)
end)

--- Journal foundation: everything a future journal tab needs, already grouped.
function RPCore.Presentation.Journal(player)
    local active, done = nil, {}
    local current = RPCore.Instances.CurrentFor(player)
    if current and current.status == S.ACTIVE then active = RPCore.Presentation.Snapshot(current) end
    for _, inst in ipairs(RPCore.Instances.HistoryFor(player)) do
        done[#done + 1] = RPCore.Presentation.Snapshot(inst)
    end
    return { type = "journal", active = active, history = done }
end

function RPCore.Presentation.SendJournal(player) send(player, RPCore.Presentation.Journal(player)) end
