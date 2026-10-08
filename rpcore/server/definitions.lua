--- Activity DEFINITIONS: the static, server-authored description of an activity.
-- A definition is data plus optional hooks; instances (server/instances.lua)
-- are the live, per-run copies. Content modules register definitions here.
--
--   RPCore.Definitions.Register({
--     id = "my.activity", name = "…", description = "…",
--     offerTimeoutMs = 60000,                      -- optional; 0/nil = never lapses
--     reward = { kind = "currency", amount = 500 },-- optional; kind is resolved by RPCore.Rewards
--     objectives = {
--       { id = "first", title = "…", description = "…",
--         completeOn = { event = "some.event",
--                        where = { key = value },                 -- data match (usable from exports)
--                        match = function(data, instance) return true end },  -- in-resource only
--         onActivate = function(instance, objective) end },  -- optional hook
--     },
--   })
RPCore.Definitions = {}
local registry = {}

local function fail(why) return nil, why end

function RPCore.Definitions.Register(def)
    if type(def) ~= "table" then return fail("definition must be a table") end
    if type(def.id) ~= "string" or def.id == "" then return fail("definition.id required") end
    if registry[def.id] then return fail("definition already registered: " .. def.id) end
    if type(def.name) ~= "string" or def.name == "" then return fail("definition.name required") end
    if type(def.objectives) ~= "table" or #def.objectives == 0 then return fail("definition needs objectives") end
    local seen = {}
    for i, o in ipairs(def.objectives) do
        if type(o.id) ~= "string" or o.id == "" or seen[o.id] then return fail("objective " .. i .. ": bad or duplicate id") end
        if type(o.title) ~= "string" or o.title == "" then return fail("objective " .. o.id .. ": title required") end
        if type(o.completeOn) ~= "table" or type(o.completeOn.event) ~= "string" then
            return fail("objective " .. o.id .. ": completeOn.event required")
        end
        if o.completeOn.where ~= nil and type(o.completeOn.where) ~= "table" then
            return fail("objective " .. o.id .. ": completeOn.where must be a table")
        end
        seen[o.id] = true
    end
    registry[def.id] = def
    RPCore.Log.debug(("definition registered: %s (%d objectives)"):format(def.id, #def.objectives))
    return def
end

function RPCore.Definitions.Get(id) return registry[id] end

--- Remove a definition (used when its owning resource re-registers after a restart).
function RPCore.Definitions.Unregister(id) registry[id] = nil end

function RPCore.Definitions.List()
    local out = {}
    for id in pairs(registry) do out[#out + 1] = id end
    table.sort(out)
    return out
end
