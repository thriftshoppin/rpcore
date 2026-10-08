--- RPCore server core: namespace, logging, clock, a tiny event bus.
-- The bus is how layers talk without knowing each other: the engine emits
-- facts ("activity.transition"), presentation and diagnostics subscribe.
RPCore = RPCore or {}
local Config = RPCore.Config

RPCore.VERSION = "0.2.0-beta.1"

-- ── logging (Open77.log is the repository convention) ──────────────────────
local function log(level, text)
    local fn = Open77 and Open77.log and Open77.log[level]
    if type(fn) == "function" then fn("[rpcore] " .. text) else print("[rpcore] " .. text) end
end
RPCore.Log = {
    info  = function(t) log("info", t) end,
    warn  = function(t) log("warn", t) end,
    error = function(t) log("error", t) end,
    --- Developer diagnostics: silent unless Config.debug.
    debug = function(t) if Config.debug then log("info", "[debug] " .. t) end end,
}

-- ── clock: `os` does not exist in this sandbox ──────────────────────────────
--- Monotonic milliseconds (same unit as the client's Open77.time.monotonic).
function RPCore.Now() return GetGameTimer() end
--- Wall-clock seconds when the platform offers it, else nil (never fabricated).
function RPCore.Unix()
    local t = Open77 and Open77.time and Open77.time.unix
    if type(t) ~= "function" then return nil end
    local ok, v = pcall(t)
    return ok and tonumber(v) or nil
end

-- ── event bus ───────────────────────────────────────────────────────────────
local listeners = {}
RPCore.Bus = {}
function RPCore.Bus.On(name, fn)
    listeners[name] = listeners[name] or {}
    listeners[name][#listeners[name] + 1] = fn
end
--- A listener that errors never breaks the engine or the other listeners.
function RPCore.Bus.Emit(name, ...)
    for _, fn in ipairs(listeners[name] or {}) do
        local ok, err = pcall(fn, ...)
        if not ok then RPCore.Log.error(("listener for '%s' failed: %s"):format(name, tostring(err))) end
    end
end

--- Run `fn` on a thread, logging (not swallowing) failures. For work that yields.
function RPCore.Async(label, fn, ...)
    local args = table.pack(...)
    CreateThread(function()
        local ok, err = pcall(fn, table.unpack(args, 1, args.n))
        if not ok then RPCore.Log.error(label .. " failed: " .. tostring(err)) end
    end)
end
