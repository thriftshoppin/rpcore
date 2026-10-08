--- The RPCore demonstration activity ("Field Test").
-- Generic on purpose: no server, setting or faction is named. It exists to prove
-- the pipeline Activity -> Objective -> Event -> State -> Presentation, using only
-- the simplest interactions the platform reliably gives us (a key press and time).
RPCore.DEMO_ID = "rpcore.field_test"
local Config = RPCore.Config

RPCore.Definitions.Register({
    id = RPCore.DEMO_ID,
    name = "Field Test",
    description = "A short sequence of objectives that demonstrates the RPCore activity engine.",
    offerTimeoutMs = Config.demo.offerTimeoutMs,
    reward = Config.demo.reward,
    objectives = {
        { id = "acknowledge", title = "Acknowledge the briefing",
          description = "Press your action key to confirm you are ready.",
          completeOn = { event = "rpcore.action" } },
        { id = "standby", title = "Stand by for the signal",
          description = "Hold position while the test runs.",
          completeOn = { event = "rpcore.demo.signal" },
          -- A server-originated event: how real content resolves objectives from game logic.
          onActivate = function(inst, objective)
              local player = inst.participantList[1]
              RPCore.Events.EmitAfter(player, "rpcore.demo.signal", Config.demo.standbyMs, inst, inst.currentIndex)
          end },
        { id = "report", title = "Confirm the result",
          description = "Press your action key once more to file the report.",
          completeOn = { event = "rpcore.action" } },
    },
})
