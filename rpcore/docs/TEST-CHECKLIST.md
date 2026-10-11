# In-game test checklist (native HUD)

Test client first. Check `r6/logs/redscript_rCURRENT.log` for compile errors before anything else.

1. **Compile**: game starts; no RPCore errors; Open77 still works (spawn, map, pause).
2. **Resource load**: `rpcore` 0.4.0 starts with `rtti.native` declared (if it refuses to load, drop that line).
3. **Base HUD untouched**: health, armor, stamina, weapon, minimap, crosshair all drawn by the game. `/rpcore.vanilla` shows no `claim=hide`.
4. **No web overlay**: no RPCore vitals panel, weapon card or web crosshair on screen.
5. **Transport**: `/rpcore.hud.native.ping`, then `/rpcore.hud.native`. Record the state (`ready` or the reason).
6. **Bars appear** after a provider call: `SetVital hunger 74`, `SetVital thirst 40`, `SetPsychosis 10`. Three bars next to the vanilla bar; note direction/position/size.
7. **Toggles**: `/rpcore.hunger off` then relog: stays off. `/rpcore.thirst off`. Server `SetBarVisible hunger false 30` hides it even when ON; returns after 30 s.
8. **Direction**: hunger/thirst shrink when you lower them; cyberpsychosis grows when you raise it.
9. **Tiers** (`SetPsychosis` 10, 30, 55, 80, 95): label changes, tint+flicker from 25, ticks at 25/50/75/90.
10. **Blackwall**: from 55 check `/rpcore.hud.native` -> `blackwall=present|absent`. Report which.
11. **Relic**: at 95 check `relic=applied` or `suppressed` (chat line appears when suppressed). Watch for gameplay side effects. Leave 90+: effect removed.
12. **Overrides**: `ForceTier breach 20 test`: breach look, gone after 20 s. Kill the calling resource mid-override: still clears. `ReleaseTier` returns to automatic.
13. **Stale guard**: stop `rpcore` while at Psychosis: bars/effects clear (`RPCoreHudClear`). Block the feed instead: effects drop to Stable in ~15 s.
14. **Co-wrapping**: with Open77 active and health claimed hidden, vanilla bar hides but RPCore bars stay; no duplicate/blocked wrappers.
15. **Menus/death/photo mode**: bars hide and return with the HUD; HOME hides them too.
16. **Denied permission**: revoke `rtti.native`: one chat message, no retry loop, base HUD fine.
