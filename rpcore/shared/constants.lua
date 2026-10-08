--- RPCore constants shared by both runtimes. Names only; no behaviour.
RPCore = RPCore or {}

--- Activity lifecycle. See server/instances.lua for the transition table.
RPCore.State = {
    CREATED = "created", OFFERED = "offered", ACCEPTED = "accepted", ACTIVE = "active",
    COMPLETED = "completed", DECLINED = "declined", LAPSED = "lapsed",
    FAILED = "failed", CANCELLED = "cancelled",
}

RPCore.ObjectiveState = { PENDING = "pending", ACTIVE = "active", COMPLETED = "completed" }

--- Net event names (the only wire contract between the halves).
RPCore.Net = {
    UI      = "rpcore:ui",       -- server -> client: a presentation message
    RESPOND = "rpcore:respond",  -- client -> server: accept / decline an offer
    ACTION  = "rpcore:action",   -- client -> server: a whitelisted player action
    JOURNAL = "rpcore:journal",  -- client -> server: ask for the journal snapshot
}
