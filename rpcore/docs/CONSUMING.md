# Building on RPCore (for mission / activity resources)

RPCore is the shared base. A mission resource owns its story and content; RPCore owns lifecycle, objectives, presentation and rewards.
Status: exports are written but **not yet run in-game**.

## 1. Declare the dependency
In your resource's `open77.lua`:
```lua
dependency "rpcore >=0.1.1"
```
And in `server.jsonc` `resources.load`, list `"rpcore"` **before** your resource.

## 2. Get allowed
Write exports are refused unless your resource name is in `rpcore/shared/config.lua` -> `Config.exports.allowedCallers`
(e.g. `{ "my_missions" }`). Without it every write answers `caller_denied`. Reads (`GetSnapshot`, `GetApiVersion`) are open.

## 3. Use it (server side)
```lua
local function rp(name, ...)
    local ok, a, b = pcall(function(...) return exports.rpcore[name](exports.rpcore, ...) end, ...)
    if not ok then return nil, "rpcore_unavailable" end
    return a, b
end

-- Register on your resource start (safe to repeat after you restart; refused only while a run is live).
rp("RegisterDefinition", {
    id = "my_missions.dock_run", name = "Dock Run", description = "...",
    reward = { kind = "display", label = "Dock pass" },     -- or { kind = "currency", amount = 250 } once a provider is configured
    objectives = {
        { id = "arrive", title = "Reach the dock", completeOn = { event = "my.arrived", where = { place = "dock" } } },
    },
})
local activityId = rp("StartActivity", "my_missions.dock_run", playerId)   -- offers it to the player
rp("EmitObjectiveEvent", playerId, "my.arrived", { place = "dock" })       -- from YOUR game logic
```
- Prefix your ids with your resource name; a definition can only be replaced by the resource that registered it.
- Exported objectives are data + events only (functions cannot cross resources). Your code decides when facts happen and emits them.
- Check `rp("GetApiVersion")` equals `1` if you want to guard against a future breaking change.

## 4. Not available yet
Location/zone objectives, persistence across restarts, Failed/Archived journal tabs, scheduler, NPC layer.
