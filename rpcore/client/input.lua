-- Rebindable RPCore controls. Defaults are reserved for testing and checked
-- against the supplied SIM-Night-City resource tree; players may change every
-- action here or through Open77's persistent KEY BINDINGS registry.
RPCore = RPCore or {}
RPCore.Client = RPCore.Client or {}

local Config = RPCore.Config
local RESOURCE = GetCurrentResourceName()

local bindings = {
    { id = "rpcore.settings", key = "settings", label = "Open RPCore controls" },
    { id = "rpcore.accept", key = "accept", label = "Accept activity offer" },
    { id = "rpcore.decline", key = "decline", label = "Decline activity offer" },
    { id = "rpcore.action", key = "action", label = "Advance activity action" },
    { id = "rpcore.journal", key = "journal", label = "Open activity journal" },
    { id = "rpcore.hud_toggle", key = "hudToggle", label = "Toggle RPCore HUD" },
    { id = "rpcore.layout", key = "layout", label = "Arrange RPCore HUD panels" },
}

local byId = {}
for _, binding in ipairs(bindings) do byId[binding.id] = binding end

local function effectiveKey(binding)
    local input = Open77 and Open77.input
    if input and type(input.keyFor) == "function" then
        local ok, key = pcall(input.keyFor, binding.id)
        if ok and type(key) == "string" and key ~= "" then return key end
    end
    return tostring(Config.keys[binding.key] or "UNBOUND")
end

local function sheet()
    local out = {}
    for _, binding in ipairs(bindings) do
        out[#out + 1] = { id = binding.id, label = binding.label, key = effectiveKey(binding) }
    end
    return out
end

local function publishSheet()
    RPCore.PagePost("rpcore:keybinds", { bindings = sheet() })
end
RPCore.Client.PublishKeybinds = publishSheet

local function respond(response)
    local id = RPCore.OfferOpen()
    if id then TriggerServerEvent(RPCore.Net.RESPOND, id, response) end
end

function RPCore.Client.Rebind(mappingId, key)
    local binding = byId[tostring(mappingId or "")]
    if not binding then return false, "unknown_rpcore_action" end
    if key == nil then key = Config.keys[binding.key] end
    if type(key) ~= "string" or key == "" or #key > 32 then return false, "invalid_key" end
    local input = Open77 and Open77.input
    if not input or type(input.rebind) ~= "function" then return false, "keybind_api_unavailable" end

    local ok, accepted, reason = pcall(input.rebind, RESOURCE, binding.id, key)
    if not ok then return false, tostring(accepted) end
    if accepted ~= true then return false, tostring(reason or "rebind_refused") end
    publishSheet()
    return true, effectiveKey(binding)
end

local function toggleJournal()
    local open = not RPCore.JournalOpen()
    RPCore.SetJournalOpen(open)
    RPCore.PagePost("rpcore:journal", { open = open })
    if open then TriggerServerEvent(RPCore.Net.JOURNAL) end
end

local handlers = {
    settings = function() RPCore.ToggleSettings() end,
    accept = function() respond("accept") end,
    decline = function() respond("decline") end,
    action = function() TriggerServerEvent(RPCore.Net.ACTION, "rpcore.action") end,
    journal = toggleJournal,
    hudToggle = function()
        if RPCore.Hud and type(RPCore.Hud.Toggle) == "function" then RPCore.Hud.Toggle() end
    end,
    layout = function()
        if RPCore.Layout and type(RPCore.Layout.Toggle) == "function" then RPCore.Layout.Toggle() end
    end,
}

local function register(binding)
    local input = Open77 and Open77.input
    if not input or type(input.registerKeyMapping) ~= "function" then
        print("[rpcore] key mapping API unavailable: " .. binding.id)
        return
    end
    local spec = {
        id = binding.id,
        name = "RPCore: " .. binding.label,
        key = Config.keys[binding.key],
        hold = false,
        onPressed = handlers[binding.key],
    }
    local ok, accepted, effective = pcall(input.registerKeyMapping, spec)
    if not ok or accepted ~= true then
        print(("[rpcore] key mapping '%s' failed: %s"):format(binding.id,
            tostring(ok and effective or accepted)))
    end
end

function RPCore.SettingsOpen()
    return RPCore._settingsOpen == true
end

function RPCore.JournalOpen()
    return RPCore._journalOpen == true
end

function RPCore.SetJournalOpen(open)
    RPCore._journalOpen = open == true
end

AddEventHandler("onClientResourceStart", function(name)
    if name ~= RESOURCE then return end
    for _, binding in ipairs(bindings) do register(binding) end
    publishSheet()
end)

AddEventHandler("open77:keybinds:changed", publishSheet)
