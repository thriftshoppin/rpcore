-- SIMNC (owner, 2026-10-05): "use what open77 gave us as the normal crosshair,
-- specifically in third person".
--
-- Open77's reticle (the open77_reticle client bootstrap, not ours to change)
-- only draws in third person WHILE AIMING, so a third-person player with a
-- weapon out had no crosshair at all -- and with a katana, none even when
-- raised. This draws THE SAME reticle (same cyan ticks, same dark rim) as the
-- normal third-person crosshair: whenever a weapon is out, tighter while aimed
-- in. The moment open77_reticle draws its own, this one steps aside, so the
-- two never stack. First person is untouched (the vanilla crosshair).
local page, ready, lastShown, lastAim

local function thirdPerson(state)
	return state ~= nil and state.available == true and state.engaged == true and state.camera == 'open77_rig'
end

--- Aimed in, from the animation graph (also sees a raised katana).
local function aimedIn(state)
	local ok, v = pcall(Open77.players.isAiming)
	if ok and v ~= nil then return v == true end
	ok, v = pcall(Open77.character.isAiming)
	if ok and v ~= nil then return v == true end
	return state ~= nil and state.aiming == true
end

local function wanted()
	-- A future per-player preference provider can switch this off.
	local hud = RPCore.Hud and RPCore.Hud.State and RPCore.Hud.State() or nil
	if RPCore.Hud and RPCore.Hud.Shown and not RPCore.Hud.Shown() then return false, false end
	if type(hud) == 'table' and type(hud.prefs) == 'table' and hud.prefs.hudCrosshair == 'off' then return false, false end
	local okA, alive = pcall(Open77.character.isAlive)
	local okW, armed = pcall(Open77.character.isArmed)
	local okC, captured = pcall(Open77.input.isCaptured)
	if not (okA and alive == true and okW and armed == true) or (okC and captured == true) then return false, false end
	local okP, state = pcall(Open77.perspective.state)
	if not okP or not thirdPerson(state) then return false, false end
	-- open77_reticle's own condition: it is drawing, so this one is not.
	if state.body == 'proxy' and state.input == 'player' and state.aiming == true then return false, false end
	return true, aimedIn(state)
end

local function refresh(force)
	if not page or not ready then return end
	local show, aiming = wanted()
	if force or show ~= lastShown or aiming ~= lastAim then
		lastShown, lastAim = show, aiming
		page:send('crosshair:state', { visible = show, aiming = aiming })
	end
end

AddEventHandler('onClientResourceStart', function(name)
	if name ~= GetCurrentResourceName() then return end
	local reason
	page, reason = Open77.webui.create({
		entry = 'web/simnc/crosshair.html', layer = 'hud', width = 1920, height = 1080,
		fps = 30, zIndex = 850, transparent = true, visible = true,
	})
	if not page then
		Open77.log.error('[rpcore] crosshair page failed: ' .. tostring(reason))
		return
	end
	page:on('crosshair:ready', function()
		ready = true
		refresh(true)
	end)
	CreateThread(function()
		while true do
			refresh(false)
			Wait(16)
		end
	end)
end)
