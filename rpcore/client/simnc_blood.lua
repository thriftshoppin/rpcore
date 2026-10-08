-- SIMNC: BLOOD ON THE SCREEN when a blade cuts you (sent by simnc_core's
-- roleplay hit messages as 'simnc:blood'). Drawn on its own HUD surface at the
-- BOTTOM of the stack (zIndex 10): the HUD (600), OPX's UI and chat (700), the
-- crosshair (850) and every menu draw over it. The page only ever paints the
-- screen edges, away from the HUD corners and the aim point, and every splatter
-- fades out on its own. Made on the first cut, not at load.
local page, ready, queued = nil, false, {}

local function create()
    if page then return end
    local surface, err = Open77.webui.create({
        entry = "web/simnc/blood.html",
        layer = "hud",
        zIndex = 10,
        fps = 30,
        transparent = true,
        visible = true,
    })
    if not surface then
        print("[rpcore] blood layer failed: " .. tostring(err))
        return
    end
    page = surface
    page:on("blood:ready", function()
        ready = true
        for _, hit in ipairs(queued) do page:send("blood:hit", hit) end
        queued = {}
    end)
end

RegisterNetEvent("simnc:blood", function(hit)
    if type(hit) ~= "table" then return end
    local clean = { zone = tostring(hit.zone or "body"), side = tostring(hit.side or ""), heavy = hit.heavy == true }
    create()
    if not page then return end
    if ready then page:send("blood:hit", clean)
    elseif #queued < 3 then queued[#queued + 1] = clean end
end)

AddEventHandler("onClientResourceStop", function(name)
    if name ~= GetCurrentResourceName() or not page then return end
    page:destroy()
    page, ready, queued = nil, false, {}
end)
