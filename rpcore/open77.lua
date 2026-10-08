--- RPCore: a server-agnostic RP activity framework for Open77.
-- Owns the machinery (activities, objectives, state, presentation, rewards).
-- The server owns the content: register your own definitions and plug in your
-- own economy. Nothing in this resource names a specific server.
--
-- SIMNC state remains an optional compatibility source during the HUD move;
-- RPCore itself depends on EventCore for its server-side presentation route.

resource "rpcore"
version "0.2.0-beta.1"
open77_version ">=0.0.1"
auto_start true
dependency "eventcore >=0.3.0-beta.1"

-- network.events : server <-> client twins (offer answers, key actions, journal)
-- input.actions  : rebindable key mappings (controls, accept / decline / action)
-- local.events   : `open77:menuStateChanged`, so the HUD steps aside for game menus
-- Ported HUD surfaces read the current SIMNC client-state export when it is
-- present and otherwise remain inert; preserve the previous resource's reads.
permissions {
    "network.events",
    "input.actions",
    "local.events",
    "players.stats.read",
    "player.weapons.read",
    "players.read",
    "player.aim.read",
}

shared_script "shared/constants.lua"
shared_script "shared/config.lua"

server_script "server/core.lua"
server_script "server/eventcore.lua"
server_script "server/definitions.lua"
server_script "server/instances.lua"
server_script "server/objectives.lua"
server_script "server/rewards.lua"
server_script "server/presentation.lua"
server_script "server/net.lua"
server_script "server/commands.lua"
server_script "server/exports.lua"
server_script "server/demo.lua"
server_script "server/boot.lua"
server_script "server/simnc_hud.lua"

client_script "client/main.lua"
client_script "client/input.lua"
client_script "client/simnc_hud.lua"
client_script "client/simnc_weapon.lua"
client_script "client/simnc_crosshair.lua"
client_script "client/simnc_blood.lua"

web_files { "web/**" }
