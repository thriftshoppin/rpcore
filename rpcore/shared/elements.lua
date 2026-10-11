--- RPCore HUD element registry (loaded on both server and client).
--
-- Every HUD element RPCore can show, hide, fade or move has one entry here.
-- EventCore (or any allowed resource) addresses elements by id; the server
-- validates every request against this table before anything reaches a player.
--
--   kind "native" : a vanilla Cyberpunk widget driven through Open77.hud.
--                   Supports visibility only (the game owns its position).
--   kind "panel"  : an RPCore WebUI panel. Supports visible / opacity / placement
--                   (placement is the same x,y,scale the F9 layout editor uses).
--   kind "gauge"  : one meter or badge inside a panel. Supports visible / opacity.
--
-- Control state is an OVERRIDE layer on top of the player's own F9 layout:
-- an override placement wins while it is set, and removing it hands the element
-- back to the player's saved position.
RPCore = RPCore or {}
local Config = RPCore.Config or {}

local Elements = { list = {}, byId = {} }
RPCore.Elements = Elements

local PANEL = { visible = true, opacity = true, placement = true }
local GAUGE = { visible = true, opacity = true }
local NATIVE = { visible = true }

local function add(def)
    if type(def.id) ~= "string" or Elements.byId[def.id] then return end
    Elements.list[#Elements.list + 1] = def
    Elements.byId[def.id] = def
end

-- Native vanilla components come from Config.vanilla (native + extra).
local function addNative(entry)
    if type(entry) ~= "table" or type(entry.component) ~= "string" then return end
    if not entry.component:match("^[%w_%-%.]+$") then return end
    add({
        id = "vanilla." .. entry.component,
        kind = "native",
        label = tostring(entry.label or entry.component),
        component = entry.component,
        default = entry.default,        -- true | false | nil
        mirror = entry.mirror,          -- RPCore element that replaces it, if any
        supports = NATIVE,
    })
end
local vanilla = type(Config.vanilla) == "table" and Config.vanilla or {}
for _, entry in ipairs(vanilla.native or {}) do addNative(entry) end
for _, entry in ipairs(vanilla.extra or {}) do addNative(entry) end

-- RPCore panels. Ids match the data-layout-id values the pages already use,
-- so overrides and the player's F9 layout address the same elements.
add({ id = "vitals",     kind = "panel", surface = "vitals",     label = "Vitals panel",     supports = PANEL })
add({ id = "occupation", kind = "panel", surface = "vitals",     label = "Occupation panel", supports = PANEL })
add({ id = "weapon",     kind = "panel", surface = "weapon",     label = "Weapon card",      supports = PANEL })
add({ id = "stack",      kind = "panel", surface = "activities", label = "Activity cards",   supports = PANEL })
add({ id = "journal",    kind = "panel", surface = "activities", label = "Journal",          supports = PANEL })
add({ id = "controls",   kind = "panel", surface = "activities", label = "Controls panel",   supports = PANEL })

-- RPCore gauges inside the vitals panel.
for _, g in ipairs({
    { "health",  "Health meter" },   { "stamina", "Stamina meter" },
    { "armor",   "Armor meter" },    { "breath",  "Breath meter" },
    { "food",    "Hunger meter" },   { "water",   "Thirst meter" },
    { "sanity",  "Cyberpsychosis meter" },
}) do
    add({ id = "vital." .. g[1], kind = "gauge", surface = "vitals", label = g[2], supports = GAUGE })
end
add({ id = "level", kind = "gauge", surface = "vitals", label = "Level badge", supports = GAUGE })

local function finite(value)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
end
local function clamp(value, lo, hi) return math.max(lo, math.min(hi, value)) end

Elements.MIN_SCALE, Elements.MAX_SCALE = 0.35, 1 -- same bounds as the F9 layout editor

function Elements.Get(id) return Elements.byId[id] end

--- Plain-data copy of the catalog (safe to return across resources).
function Elements.Catalog()
    local out = {}
    for index, def in ipairs(Elements.list) do
        out[index] = {
            id = def.id, kind = def.kind, label = def.label, surface = def.surface,
            component = def.component, mirror = def.mirror,
            supports = {
                visible = def.supports.visible == true,
                opacity = def.supports.opacity == true,
                placement = def.supports.placement == true,
            },
        }
    end
    return out
end

--- Validate a control patch for one element.
-- Returns a clean patch table, or nil + a machine-readable reason.
function Elements.Sanitize(id, patch)
    local def = Elements.byId[id]
    if not def then return nil, "unknown_element" end
    if type(patch) ~= "table" then return nil, "invalid_patch" end

    local clean, any = {}, false
    if patch.visible ~= nil then
        if not def.supports.visible then return nil, "visible_unsupported" end
        if type(patch.visible) ~= "boolean" then return nil, "invalid_visible" end
        clean.visible, any = patch.visible, true
    end
    if patch.opacity ~= nil then
        if not def.supports.opacity then return nil, "opacity_unsupported" end
        local opacity = finite(patch.opacity)
        if not opacity then return nil, "invalid_opacity" end
        clean.opacity, any = clamp(opacity, 0, 1), true
    end
    if patch.placement ~= nil then
        if not def.supports.placement then return nil, "placement_unsupported" end
        local p = patch.placement
        if type(p) ~= "table" then return nil, "invalid_placement" end
        local x, y = finite(p.x), finite(p.y)
        if not x or not y then return nil, "invalid_placement" end
        local scale = nil
        if p.scale ~= nil then
            scale = finite(p.scale)
            if not scale then return nil, "invalid_placement" end
            scale = clamp(scale, Elements.MIN_SCALE, Elements.MAX_SCALE)
        end
        clean.placement = { x = clamp(x, 0, 1), y = clamp(y, 0, 1), scale = scale }
        any = true
    end
    if not any then return nil, "empty_patch" end
    return clean
end
