--- RPCore: a server-agnostic RP activity framework for Open77.
-- Owns the machinery (activities, objectives, state, presentation, rewards).
-- The server owns the content: register your own definitions and plug in your
-- own economy. Nothing in this resource names a specific server.
--
-- RPCore owns the player-facing HUD and uses EventCore for the server-owned
-- client-safe state feed.

resource "rpcore"
version "0.4.0"
open77_version ">=0.0.1"
auto_start true
dependency "eventcore >=0.6.1"
-- RPCore owns persistent HUD WebUI surfaces; recreate them after a reconnect
-- rather than trying to reuse stale CEF pages across a resource reload.
reload_policy "reconnect"

-- network.events : server <-> client twins (offer answers, key actions, journal)
-- input.actions  : rebindable key mappings (controls, accept / decline / action)
-- local.events   : `open77:menuStateChanged`, so the HUD steps aside for game menus
-- The server publishes HUD state through EventCore; clients only render it.
-- rtti.native    : NEW. Documented permission (open2077.net/docs/rtti): lets client/native_hud.lua
--                  call the redscript pack's RPCoreHud* functions through Open77.rtti. It is a
--                  privileged client API, so the server admin must approve it in Warden. Without
--                  it RPCore still loads; the native bars just never appear and /rpcore.hud.native
--                  says why.
permissions {
    "network.events",
    "input.actions",
    "local.events",
    "players.stats.read",
    "players.life.read",
    "player.weapons.read",
    "players.read",
    "player.aim.read",
    "ui.vanilla.hud",
    "ui.vanilla.map",
    "map.read",
    "map.control",
    "rtti.native",
}

shared_script "shared/constants.lua"
shared_script "shared/config.lua"
shared_script "shared/vitals.lua"
shared_script "shared/elements.lua"

server_script "server/core.lua"
server_script "server/eventcore.lua"
server_script "server/definitions.lua"
server_script "server/instances.lua"
server_script "server/objectives.lua"
server_script "server/rewards.lua"
server_script "server/presentation.lua"
server_script "server/net.lua"
server_script "server/map.lua"
server_script "server/commands.lua"
server_script "server/exports.lua"
server_script "server/demo.lua"
server_script "server/boot.lua"
server_script "server/vitals.lua"
server_script "server/hud_state.lua"
server_script "server/elements.lua"

client_script "client/main.lua"
client_script "client/map.lua"
client_script "client/layout.lua"
client_script "client/vanilla.lua"
client_script "client/native_hud.lua"
client_script "client/input.lua"
client_script "client/hud.lua"
client_script "client/weapon.lua"
client_script "client/crosshair.lua"
client_script "client/blood.lua"

-- Client pack (redscript) the launcher installs BEFORE the game boots when a player connects:
-- r6/scripts/RPCore/*.reds, built by tools/build-client-pack.py. redscript is EXECUTABLE content, so
-- the server must either run `requiredMods.unsecured: true` or have this exact SHA-256 verified
-- (Warden -> Mods -> request review). `requiredMods.enabled` must be true. See docs/NATIVE-HUD.md.
preload_mod "dist/rpcore-hud.zip"

web_files { "web/**" }
