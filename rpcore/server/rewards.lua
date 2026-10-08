--- Reward interface. RPCore has no economy of its own.
-- A reward is `{ kind = "...", ... }`. A KIND handler pays it; the built-in
-- "currency" kind delegates to the PROVIDER selected in Config.reward.provider.
--   RPCore.Rewards.RegisterKind("item", function(player, spec, inst) return true end)
--   RPCore.Rewards.RegisterProvider("myeconomy", function(player, amount, inst, provider) ... end)
RPCore.Rewards = {}
local Config = RPCore.Config
local kinds, providers = {}, {}

function RPCore.Rewards.RegisterKind(kind, fn) kinds[kind] = fn end
function RPCore.Rewards.RegisterProvider(name, fn) providers[name] = fn end

--- Display text for a reward spec (presentation asks; payment is separate).
function RPCore.Rewards.Describe(spec)
    if type(spec) ~= "table" then return nil end
    if spec.kind == "currency" then return Config.reward.currencyFormat:format(tonumber(spec.amount) or 0) end
    return spec.label
end

-- type = "none": a reward that is displayed but pays nothing.
providers.none = function() return true, "no_provider" end

-- type = "export": a server-configured export, called lazily at grant time.
providers.export = function(player, amount, inst, p)
    if type(p.resource) ~= "string" or type(p.export) ~= "string" then return nil, "provider_misconfigured" end
    local promise, refused = Open77.exports.call(p.resource, p.export, player, p.currency, amount, p.reason or "rpcore")
    if promise == nil then return nil, refused or "provider_unavailable" end
    local ok, why = promise:await()
    -- Bridge-style answers: true, or nil + reason. A Result table carries .ok.
    if type(ok) == "table" then if ok.ok then return true end return nil, ok.error or "refused" end
    if ok then return true end
    return nil, why or "refused"
end

-- kind = "display": shown on the completion card, pays nothing (no economy needed).
kinds.display = function() return true end

kinds.currency = function(player, spec, inst)
    local amount = tonumber(spec.amount)
    if not amount or amount <= 0 then return nil, "bad_amount" end
    local p = Config.reward.provider or {}
    local provider = providers[p.type or "none"]
    if not provider then return nil, "unknown_provider" end
    return provider(player, amount, inst, p)
end

--- Pay every participant. YIELDS (provider calls may await): run on a thread.
-- Sets inst.reward.status = "granted" | "failed" | "none" and announces it.
function RPCore.Rewards.Grant(inst)
    local spec = inst.reward.spec
    if type(spec) ~= "table" then inst.reward.status = "none" return end
    local handler = kinds[spec.kind]
    if not handler then inst.reward.status = "failed" inst.reward.why = "unknown_kind" else
        local all = true
        for _, player in ipairs(inst.participantList) do
            if inst.participants[player] then
                local ok, res, why = pcall(handler, player, spec, inst)
                if not ok or not res then
                    all = false
                    inst.reward.why = ok and why or tostring(res)
                    RPCore.Log.warn(("%s reward failed for %d: %s"):format(inst.id, player, tostring(inst.reward.why)))
                end
            end
        end
        inst.reward.status = all and "granted" or "failed"
    end
    RPCore.Bus.Emit("activity.reward", inst)
end
