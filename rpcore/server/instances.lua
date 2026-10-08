--- Activity INSTANCES: one live run of a definition, and its lifecycle.
-- The only module that mutates activity state. It knows nothing about UI;
-- it announces what happened on RPCore.Bus and presentation reacts.
--
--   created -> offered -> accepted -> active -> completed
--   (side exits) declined | lapsed | failed | cancelled
--
-- Bus events: activity.transition(inst, from, to, reason)
--             objective.activated(inst, index)   objective.completed(inst, index)
RPCore.Instances = {}
local S, OS = RPCore.State, RPCore.ObjectiveState

local TRANSITIONS = {
    [S.CREATED]  = { [S.OFFERED] = true, [S.CANCELLED] = true },
    [S.OFFERED]  = { [S.ACCEPTED] = true, [S.DECLINED] = true, [S.LAPSED] = true, [S.CANCELLED] = true },
    [S.ACCEPTED] = { [S.ACTIVE] = true, [S.CANCELLED] = true },
    [S.ACTIVE]   = { [S.COMPLETED] = true, [S.FAILED] = true, [S.CANCELLED] = true },
}
local TERMINAL = { [S.COMPLETED] = true, [S.DECLINED] = true, [S.LAPSED] = true, [S.FAILED] = true, [S.CANCELLED] = true }

local byId, byPlayer, history, counter = {}, {}, {}, 0

local function stamp(inst, key)
    inst.timestamps[key] = RPCore.Now()
    inst.timestamps[key .. "Unix"] = RPCore.Unix()
end

--- Create an instance in `created`. `participants` is a list of player ids.
function RPCore.Instances.Create(definitionId, participants)
    local def = RPCore.Definitions.Get(definitionId)
    if not def then return nil, "unknown_definition" end
    if type(participants) ~= "table" or #participants == 0 then return nil, "no_participants" end
    counter = counter + 1
    local inst = {
        id = ("act_%d"):format(counter),
        definitionId = def.id, name = def.name, description = def.description or "",
        status = S.CREATED, objectives = {}, currentIndex = 0,
        participants = {}, participantList = {}, timestamps = {}, transitions = {},
        reward = { spec = def.reward, status = def.reward and "pending" or "none" },
        result = nil,
    }
    for i, o in ipairs(def.objectives) do
        inst.objectives[i] = { id = o.id, title = o.title, description = o.description or "", status = OS.PENDING }
    end
    for _, p in ipairs(participants) do
        p = tonumber(p)
        if p and not inst.participants[p] then
            inst.participants[p] = true
            inst.participantList[#inst.participantList + 1] = p
        end
    end
    stamp(inst, "createdAt")
    byId[inst.id] = inst
    for _, p in ipairs(inst.participantList) do
        byPlayer[p] = byPlayer[p] or {}
        byPlayer[p][#byPlayer[p] + 1] = inst
    end
    inst.transitions[1] = { to = S.CREATED, at = RPCore.Now() }
    RPCore.Log.debug(("%s created (%s) participants=%d"):format(inst.id, def.id, #inst.participantList))
    return inst
end

function RPCore.Instances.Get(id) return byId[id] end

--- How many non-finished instances were created from a definition.
function RPCore.Instances.CountLive(definitionId)
    local n = 0
    for _, inst in pairs(byId) do
        if inst.definitionId == definitionId and not TERMINAL[inst.status] then n = n + 1 end
    end
    return n
end

--- The activity a player is currently inside (offered / accepted / active), or nil.
function RPCore.Instances.CurrentFor(player)
    for _, inst in ipairs(byPlayer[player] or {}) do
        if not TERMINAL[inst.status] then return inst end
    end
    return nil
end

function RPCore.Instances.HistoryFor(player) return history[player] or {} end
function RPCore.Instances.IsTerminal(inst) return TERMINAL[inst.status] == true end

local function archive(inst)
    local cap = RPCore.Config.limits.historyPerPlayer
    for _, p in ipairs(inst.participantList) do
        local list = history[p] or {}
        history[p] = list
        table.insert(list, 1, inst)
        while #list > cap do table.remove(list) end
        local live = byPlayer[p] or {}
        for i = #live, 1, -1 do if live[i] == inst then table.remove(live, i) end end
    end
end

--- The one gate for every status change. Returns true, or nil + reason.
function RPCore.Instances.Transition(inst, to, reason)
    local from = inst.status
    if not (TRANSITIONS[from] and TRANSITIONS[from][to]) then
        RPCore.Log.warn(("%s refused transition %s -> %s"):format(inst.id, from, to))
        return nil, "invalid_transition"
    end
    inst.status = to
    inst.transitions[#inst.transitions + 1] = { from = from, to = to, reason = reason, at = RPCore.Now() }
    if to == S.OFFERED then stamp(inst, "offeredAt")
    elseif to == S.ACCEPTED then stamp(inst, "acceptedAt")
    elseif to == S.ACTIVE then stamp(inst, "startedAt")
    elseif TERMINAL[to] then stamp(inst, "endedAt"); inst.result = { outcome = to, reason = reason } end
    RPCore.Log.debug(("%s %s -> %s (%s)"):format(inst.id, from, to, tostring(reason)))
    RPCore.Bus.Emit("activity.transition", inst, from, to, reason)
    if TERMINAL[to] then
        archive(inst)
        -- Finished runs stay readable through history; the live index forgets them.
        SetTimeout(600000, function() byId[inst.id] = nil end)
    end
    return true
end

local function activateObjective(inst, index)
    local o = inst.objectives[index]
    o.status = OS.ACTIVE
    inst.currentIndex = index
    RPCore.Bus.Emit("objective.activated", inst, index)
    local def = RPCore.Definitions.Get(inst.definitionId)
    local hook = def and def.objectives[index].onActivate
    if type(hook) == "function" then
        local ok, err = pcall(hook, inst, o)
        if not ok then RPCore.Log.error(("%s onActivate failed: %s"):format(inst.id, tostring(err))) end
    end
end

--- Offer (created -> offered). Lapses after the definition's offerTimeoutMs.
function RPCore.Instances.Offer(inst)
    local ok, why = RPCore.Instances.Transition(inst, S.OFFERED, "offered")
    if not ok then return nil, why end
    local def = RPCore.Definitions.Get(inst.definitionId)
    local timeout = def and tonumber(def.offerTimeoutMs) or 0
    if timeout > 0 then
        SetTimeout(timeout, function()
            if inst.status == S.OFFERED then RPCore.Instances.Transition(inst, S.LAPSED, "offer_timeout") end
        end)
    end
    return true
end

--- A participant accepts: accepted, then active with the first objective live.
function RPCore.Instances.Accept(inst, player)
    if not inst.participants[player] then return nil, "not_participant" end
    local ok, why = RPCore.Instances.Transition(inst, S.ACCEPTED, "accepted")
    if not ok then return nil, why end
    RPCore.Instances.Transition(inst, S.ACTIVE, "started")
    activateObjective(inst, 1)
    return true
end

function RPCore.Instances.Decline(inst, player)
    if not inst.participants[player] then return nil, "not_participant" end
    return RPCore.Instances.Transition(inst, S.DECLINED, "declined")
end

function RPCore.Instances.Cancel(inst, reason) return RPCore.Instances.Transition(inst, S.CANCELLED, reason or "cancelled") end
function RPCore.Instances.Fail(inst, reason) return RPCore.Instances.Transition(inst, S.FAILED, reason or "failed") end

--- Complete the CURRENT objective; advances or completes the activity.
function RPCore.Instances.CompleteCurrentObjective(inst)
    if inst.status ~= S.ACTIVE then return nil, "not_active" end
    local index = inst.currentIndex
    local o = inst.objectives[index]
    if not o or o.status ~= OS.ACTIVE then return nil, "no_active_objective" end
    o.status = OS.COMPLETED
    o.completedAt = RPCore.Now()
    RPCore.Bus.Emit("objective.completed", inst, index)
    if index < #inst.objectives then
        activateObjective(inst, index + 1)
    else
        RPCore.Instances.Transition(inst, S.COMPLETED, "all_objectives_completed")
    end
    return true
end

--- Drop a leaving player; a run with nobody left is cancelled.
function RPCore.Instances.PlayerLeft(player)
    for _, inst in ipairs({ table.unpack(byPlayer[player] or {}) }) do
        if not TERMINAL[inst.status] then
            inst.participants[player] = nil
            local any = false
            for _ in pairs(inst.participants) do any = true break end
            if not any then RPCore.Instances.Cancel(inst, "participant_left") end
        end
    end
    byPlayer[player] = nil
end

--- Developer diagnostics. Never sent to players.
function RPCore.Instances.Diagnostics()
    local rows = {}
    for _, inst in pairs(byId) do
        local n = 0
        for _ in pairs(inst.participants) do n = n + 1 end
        rows[#rows + 1] = ("%s def=%s state=%s objective=%d/%d participants=%d created=%s")
            :format(inst.id, inst.definitionId, inst.status, inst.currentIndex, #inst.objectives, n,
                tostring(inst.timestamps.createdAt))
    end
    table.sort(rows)
    return rows
end
