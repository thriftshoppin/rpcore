-- Blade-hit overlay rendered on its own low-priority HUD surface. Menus, the HUD, and the crosshair draw over it.
-- The owning combat resource sends validated hit details through RPCore's client event.
local page, ready, queued = nil, false, {}

local function create()
    if page then return end
    local surface, err = Open77.webui.create({
        entry = "web/hud/blood.html",
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

RegisterNetEvent("rpcore:combat:blood", function(hit)
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
