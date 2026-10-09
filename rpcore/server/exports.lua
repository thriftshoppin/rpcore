--- Public export surface: how OTHER resources use RPCore.
-- Repository rules this follows (see rp_zones and open77_contextmenu):
--   * exports are synchronous and never yield (they read/change in-memory state only);
--   * values crossing resources are plain data -- Lua functions cannot be passed, so a
--     definition registered from outside describes its objectives as DATA
--     (`completeOn = { event = "...", where = { key = value } }`) and the consumer resolves
--     objectives by calling EmitObjectiveEvent from its own game logic;
--   * writes are refused unless the CALLING resource is named in
--     Config.exports.allowedCallers;
--     reads (GetSnapshot) are open.
--
--   exports.rpcore:RegisterDefinition(def)                  -> true | nil, reason
--   exports.rpcore:StartActivity(definitionId, players, o)  -> activityId | nil, reason
--   exports.rpcore:EmitObjectiveEvent(player, event, data)  -> number advanced | nil, reason
--   exports.rpcore:GetSnapshot(player)                      -> { active, history }
--   exports.rpcore:GetApiVersion()                          -> 1
-- Call from another resource inside pcall (a synchronous export raises when the
-- resource is not running), or through Open77.exports.call(...):await().
local Config = RPCore.Config

local MAX_DEPTH, MAX_NODES = 6, 400

--- Copy `value` as plain data, or nil + reason. Rejects functions/userdata/threads,
--- cycles and oversized trees, so nothing foreign reaches the engine.
local function plain(value, depth, budget)
    local t = type(value)
    if t == "string" or t == "number" or t == "boolean" then return value end
    if t ~= "table" then return nil, "unsupported_value_" .. t end
    if depth > MAX_DEPTH then return nil, "too_deep" end
    local out = {}
    for k, v in pairs(value) do
        budget.n = budget.n + 1
        if budget.n > MAX_NODES then return nil, "too_large" end
        local kt = type(k)
        if kt ~= "string" and kt ~= "number" then return nil, "unsupported_key" end
        local copy, why = plain(v, depth + 1, budget)
        if copy == nil then return nil, why end
        out[k] = copy
    end
    return out
end

local function callerAllowed()
    local caller = type(GetInvokingResource) == "function" and GetInvokingResource() or nil
    if type(caller) ~= "string" then return false, nil end
    for _, name in ipairs(Config.exports.allowedCallers or {}) do
        if caller == name then return true, caller end
    end
    return false, caller
end

local function guard()
    if not Config.exports.enabled then return nil, "exports_disabled" end
    local ok, caller = callerAllowed()
    if not ok then
        RPCore.Log.warn(("export refused: caller '%s' is not in Config.exports.allowedCallers"):format(tostring(caller)))
        return nil, "caller_denied"
    end
    return caller
end

local function online(player)
    local players = Open77 and Open77.players
    if players and type(players.name) == "function" then
        local ok, name = pcall(players.name, player)
        return ok and name ~= nil
    end
    return true -- platform offers no lookup here: do not invent a check
end

exports("RegisterDefinition", function(def)
    local caller, why = guard()
    if not caller then return nil, why end
    local data, bad = plain(def, 1, { n = 0 })
    if data == nil then return nil, bad end
    if type(data) ~= "table" then return nil, "definition_must_be_a_table" end
    for _, o in ipairs(type(data.objectives) == "table" and data.objectives or {}) do
        -- Hooks cannot cross resources: an exported objective is data + events only.
        o.onActivate, o.completeOn = nil, type(o.completeOn) == "table" and { event = o.completeOn.event, where = o.completeOn.where } or nil
    end
    -- A consumer that restarts registers again: the SAME owner may replace its own
    -- definition as long as no run is live (live runs index into the objective list).
    local existing = RPCore.Definitions.Get(data.id)
    if existing then
        if existing.owner ~= caller then return nil, "definition_owned_by_another_resource" end
        if RPCore.Instances.CountLive(data.id) > 0 then return nil, "definition_in_use" end
        RPCore.Definitions.Unregister(data.id)
    end
    data.owner = caller
    local def2, err = RPCore.Definitions.Register(data)
    if not def2 then return nil, err end
    RPCore.Log.info(("definition '%s' registered by %s"):format(data.id, caller))
    return true
end)

exports("StartActivity", function(definitionId, players, opts)
    local caller, why = guard()
    if not caller then return nil, why end
    if type(definitionId) ~= "string" then return nil, "bad_definition_id" end
    local list = {}
    if type(players) == "number" then list[1] = players
    elseif type(players) == "table" then for _, p in ipairs(players) do list[#list + 1] = tonumber(p) end
    else return nil, "bad_players" end
    if #list == 0 or #list > 32 then return nil, "bad_players" end
    for _, p in ipairs(list) do
        if not p or p <= 0 or not online(p) then return nil, "player_unavailable" end
        if RPCore.Instances.CurrentFor(p) then return nil, "already_in_activity" end
    end
    local inst, err = RPCore.Instances.Create(definitionId, list)
    if not inst then return nil, err end
    if not (type(opts) == "table" and opts.offer == false) then
        local ok, offerErr = RPCore.Instances.Offer(inst)
        if not ok then return nil, offerErr or "offer_failed" end
    end
    RPCore.Log.debug(("%s started by %s"):format(inst.id, caller))
    return inst.id
end)

exports("EmitObjectiveEvent", function(player, event, data)
    local caller, why = guard()
    if not caller then return nil, why end
    if type(event) ~= "string" or event == "" or #event > 100 then return nil, "bad_event" end
    local copy, bad = plain(data == nil and {} or data, 1, { n = 0 })
    if copy == nil or type(copy) ~= "table" then return nil, bad or "bad_data" end
    return RPCore.Events.Emit(player, event, copy)
end)

--- API contract version for consumers: bump only on a breaking change to these exports.
-- Open to every caller (no write, no state).
exports("GetApiVersion", function() return 1 end)

exports("GetSnapshot", function(player)
    player = tonumber(player)
    if not player then return nil, "invalid_player" end
    local j = RPCore.Presentation.Journal(player)
    return { active = j.active, history = j.history }
end)
