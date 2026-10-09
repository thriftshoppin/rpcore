# RPCore survival vitals provider

RPCore renders optional hunger, thirst, and sanity bars but does not own their
gameplay rules. A server resource that owns those values can update the HUD
through the RPCore server exports:

```lua
local pending, dispatchError = Open77.exports.call(
    "rpcore",
    "SetSurvivalVitals",
    playerId,
    {
        hunger = 74,
        hungerMax = 100,
        thirst = 61,
        thirstMax = 100,
        sanity = 18,
        sanityMax = 100,
    }
)

if not pending then
    print("RPCore HUD update could not be sent: " .. tostring(dispatchError))
else
    local ok, reason = pending:await()
    if not ok then print("RPCore HUD update failed: " .. tostring(reason)) end
end
```

`SetSurvivalVitals(playerId, values)` accepts any subset of `hunger`, `thirst`,
and `sanity`, with optional matching `hungerMax`, `thirstMax`, and `sanityMax`.
Values are clamped to `0..max`; omitted values keep their last supplied value.
Each maximum defaults to 100. `ClearSurvivalVitals(playerId)` clears all three
values and hides their bars. Invalid player IDs or non-finite values are
rejected.

The sanity value is a cyberpsychosis severity meter: 0 is calm and 100 is
maximum severity. Its bar shifts from green toward red, and the red/black
Blackwall interference grows with the value. The owning provider is responsible
for deriving this severity from its own humanity, cyberware, or sanity rules.

RPCore keeps the latest values in server memory for that player and includes
them in its normal EventCore HUD snapshot. The provider remains responsible for
decay, character persistence, and resending values after its own state loads or
after either resource restarts. Player disconnect clears RPCore's cached copy.
