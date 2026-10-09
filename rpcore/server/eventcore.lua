-- RPCore's only bridge to EventCore. Open77 gives each resource its own Lua VM,
-- so this module uses EventCore's serializable exports rather than a shared
-- EventCore global or callback-valued cross-resource events.
RPCore = RPCore or {}
RPCore.EventCore = RPCore.EventCore or {}

local state = {
    connected = false,
    version = nil,
    apiVersion = nil,
    services = {},
    lastError = "starting",
}

local queue = {}
local workerRunning = false
local MAX_QUEUE = 256

local function call(method, ...)
    if not (Open77 and Open77.exports and type(Open77.exports.call) == "function") then
        return nil, "exports_api_unavailable"
    end
    local pending, dispatchError = Open77.exports.call("eventcore", method, ...)
    if not pending then return nil, dispatchError or "eventcore_call_refused" end
    return pending:await()
end

local function refresh()
    local runtime, reason = call("GetRuntimeInfo")
    if type(runtime) ~= "table" or type(runtime.apiVersion) ~= "number" then
        state.connected = false
        state.lastError = tostring(reason or "invalid_runtime_info")
        return false, state.lastError
    end
    if runtime.apiVersion < 1 then
        state.connected = false
        state.lastError = "unsupported_eventcore_api"
        return false, state.lastError
    end

    state.connected = true
    state.version = type(runtime.version) == "string" and runtime.version or "unknown"
    state.apiVersion = runtime.apiVersion
    state.services = type(runtime.services) == "table" and runtime.services or {}
    state.lastError = nil
    return true
end

local function serviceById(serviceId)
    for _, descriptor in ipairs(state.services) do
        if descriptor.id == serviceId then return descriptor end
    end
    return nil
end

function RPCore.EventCore.Status()
    local services = {}
    for index, descriptor in ipairs(state.services) do
        services[index] = descriptor
    end
    return {
        connected = state.connected,
        version = state.version,
        apiVersion = state.apiVersion,
        services = services,
        lastError = state.lastError,
    }
end

--- Run from a host-managed server coroutine (CreateThread/RPCore.Async).
function RPCore.EventCore.Call(method, ...)
    return call(method, ...)
end

--- Refresh the EventCore runtime and advertised provider catalog.
function RPCore.EventCore.Refresh()
    return refresh()
end

--- Trusted server context. The caller must keep identity fields server-side.
function RPCore.EventCore.GetPlayerContext(playerId)
    return call("GetPlayerContext", playerId)
end

--- Current native replication-scope viewers for proximity-aware presentation.
function RPCore.EventCore.GetPlayerObservers(playerId)
    return call("GetPlayerObservers", playerId)
end

--- Query Warden's global admin/owner roles through EventCore's trusted API.
function RPCore.EventCore.IsAdmin(playerId)
    return call("IsAdmin", playerId)
end

--- Publish a client-safe RPCore HUD snapshot through EventCore's state feed.
function RPCore.EventCore.PublishClientState(playerId, channel, schemaVersion, payload)
    return call("PublishClientState", playerId, channel, schemaVersion, payload)
end

function RPCore.EventCore.ClearClientState(playerId, channel, schemaVersion)
    return call("ClearClientState", playerId, channel, schemaVersion)
end

--- Query a method only when EventCore advertises it for that provider.
function RPCore.EventCore.CallProvider(serviceId, method, ...)
    if not state.connected then return nil, "eventcore_unavailable" end
    if type(serviceId) ~= "string" or type(method) ~= "string" then
        return nil, "invalid_service_request"
    end
    local descriptor = serviceById(serviceId)
    if not descriptor then return nil, "service_unavailable" end
    local advertised = false
    for _, name in ipairs(descriptor.methods or {}) do
        if name == method then advertised = true break end
    end
    if not advertised then return nil, "method_not_advertised" end
    if type(descriptor.resource) ~= "string" or descriptor.resource == "" then
        return nil, "provider_resource_missing"
    end

    local pending, dispatchError = Open77.exports.call(descriptor.resource, method, ...)
    if not pending then return nil, dispatchError or "provider_call_refused" end
    return pending:await()
end

local function sendOne(item)
    if not state.connected then
        local ok, reason = refresh()
        if not ok then return false, reason end
    end
    -- Context/position remains a server-side integration point for later
    -- proximity-aware HUD data. A temporarily missing context snapshot must
    -- not block an ordinary RPCore presentation packet for a live session.
    local ok, reason = call("EmitClient", RPCore.Net.UI, item.player, item.message)
    if ok ~= true then return false, reason or "eventcore_emit_failed" end
    return true
end

local function runQueue()
    while #queue > 0 do
        local item = table.remove(queue, 1)
        local ok, reason = sendOne(item)
        if not ok then
            state.lastError = tostring(reason or "send_failed")
            RPCore.Log.warn("EventCore HUD delivery failed: " .. state.lastError)
        end
    end
    workerRunning = false
    if #queue > 0 then
        workerRunning = true
        RPCore.Async("EventCore HUD delivery queue", runQueue)
    end
end

--- Deliver presentation packets through EventCore's client route in order.
function RPCore.EventCore.SendClient(playerId, message)
    playerId = tonumber(playerId)
    if not playerId or playerId < 1 or playerId % 1 ~= 0 or type(message) ~= "table" then
        RPCore.Log.warn("refused invalid EventCore HUD packet")
        return false
    end
    if #queue >= MAX_QUEUE then
        RPCore.Log.warn("EventCore HUD queue full; dropping presentation packet")
        return false
    end
    queue[#queue + 1] = { player = playerId, message = message }
    if not workerRunning then
        workerRunning = true
        RPCore.Async("EventCore HUD delivery queue", runQueue)
    end
    return true
end

function RPCore.EventCore.Initialize()
    RPCore.Async("EventCore discovery", function()
        local wasConnected = state.connected
        local ok, reason = refresh()
        if ok then
            RPCore.Log.info(("EventCore %s ready (API %d, %d advertised service(s))")
                :format(state.version, state.apiVersion, #state.services))
        else
            RPCore.Log.warn("EventCore is not ready: " .. tostring(reason))
        end
        while true do
            Wait(30000)
            wasConnected = state.connected
            local updated, updateError = refresh()
            if updated then
                RPCore.Log.debug(("EventCore catalog refreshed (%d service(s))"):format(#state.services))
            elseif wasConnected then
                state.connected = false
                state.lastError = tostring(updateError)
                RPCore.Log.warn("EventCore connection lost: " .. state.lastError)
            end
        end
    end)
end
