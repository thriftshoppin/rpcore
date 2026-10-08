--- Last server script: announce readiness and log the active configuration.
RPCore.EventCore.Initialize()
RPCore.Log.info(("RPCore %s ready: %d definition(s) [%s], demo %s, reward provider '%s'"):format(
    RPCore.VERSION, #RPCore.Definitions.List(), table.concat(RPCore.Definitions.List(), ", "),
    RPCore.Config.demo.enabled and "enabled" or "disabled",
    tostring(RPCore.Config.reward.provider and RPCore.Config.reward.provider.type)))
