// RPCore native HUD -- controller extension.
//
// Extends the game's own health bar controller (healthbarWidgetGameController, a subclass of
// inkHUDGameController) with @addField / @addMethod / @wrapMethod. COOPERATIVE: every wrapper
// calls wrappedMethod() first and returns its result; no vanilla widget is hidden, moved or
// restyled. Open77 wraps the same two methods and redscript chains wrappers, so both run.
//
// FLOW
//   Lua/EventCore -> RPCoreHud* statics (store only) -> pump on this controller (every 0.1 s)
//   -> GameInstance.GetUISystem(game).QueueEvent(RPCore...Event)
//   -> cb func OnRPCore...Event on this controller -> RPCoreHudHost -> inkWidget calls.

public class RPCoreHudTick extends DelayCallback {
  public let game: GameInstance;
  public let controller: wref<healthbarWidgetGameController>;
  public let generation: Int32;

  public func Call() -> Void {
    if !IsDefined(this.controller) { return; }   // controller gone: the loop simply ends
    this.controller.RPCoreTick(this.game, this.generation);
  }
}

@addField(healthbarWidgetGameController) private let m_rpcHost: ref<RPCoreHudHost>;
@addField(healthbarWidgetGameController) private let m_rpcTest: ref<RPCoreWidgetTest>;
@addField(healthbarWidgetGameController) private let m_rpcAttached: Bool;
@addField(healthbarWidgetGameController) private let m_rpcGeneration: Int32;
@addField(healthbarWidgetGameController) private let m_rpcSeen: Int32;
@addField(healthbarWidgetGameController) private let m_rpcSeenReset: Int32;

@wrapMethod(healthbarWidgetGameController)
protected cb func OnInitialize() -> Bool {
  let result: Bool = wrappedMethod();
  this.m_rpcSeen = 0;
  this.m_rpcSeenReset = 0;
  this.RPCoreEnsureMounted();
  this.RPCoreAttach();
  return result;
}

@wrapMethod(healthbarWidgetGameController)
protected cb func OnUpdateHealthBarVisibility() -> Bool {
  let result: Bool = wrappedMethod();
  this.RPCoreEnsureMounted();
  this.RPCoreAttach();   // the player is not always attached during OnInitialize
  return result;
}

@addMethod(healthbarWidgetGameController)
private func RPCoreEnsureMounted() -> Void {
  if !IsDefined(this.m_rpcHost) { this.m_rpcHost = new RPCoreHudHost(); }
  this.m_rpcHost.Mount(this);
}

// ---- event handlers: the clean surface the server state lands on -------------------------
@addMethod(healthbarWidgetGameController)
protected cb func OnRPCoreBarDefineEvent(evt: ref<RPCoreBarDefineEvent>) -> Bool {
  this.RPCoreEnsureMounted();
  this.m_rpcHost.Define(evt);
  return true;
}

@addMethod(healthbarWidgetGameController)
protected cb func OnRPCoreBarValueEvent(evt: ref<RPCoreBarValueEvent>) -> Bool {
  if IsDefined(this.m_rpcHost) { this.m_rpcHost.Apply(evt); }
  return true;
}

@addMethod(healthbarWidgetGameController)
protected cb func OnRPCoreBarRemoveEvent(evt: ref<RPCoreBarRemoveEvent>) -> Bool {
  if IsDefined(this.m_rpcHost) { this.m_rpcHost.Remove(evt); }
  return true;
}

@addMethod(healthbarWidgetGameController)
protected cb func OnRPCoreHudResetEvent(evt: ref<RPCoreHudResetEvent>) -> Bool {
  if IsDefined(this.m_rpcHost) { this.m_rpcHost.Reset(); }
  return true;
}

// ---- attach + pump ----------------------------------------------------------------------
@addMethod(healthbarWidgetGameController)
public func RPCoreAttach() -> Void {
  if this.m_rpcAttached { return; }
  let player: ref<GameObject> = this.GetPlayerControlledObject() as GameObject;
  if !IsDefined(player) { return; }
  let game: GameInstance = player.GetGame();
  let system: ref<RPCoreHudSystem> = GameInstance.GetScriptableSystemsContainer(game).Get(n"RPCoreHudSystem") as RPCoreHudSystem;
  if !IsDefined(system) { return; }
  this.m_rpcAttached = true;
  system.attached = true;
  system.generation += 1;            // any older controller's loop stops at its next tick
  this.m_rpcGeneration = system.generation;
  this.RPCoreSchedule(game);
}

@addMethod(healthbarWidgetGameController)
private func RPCoreSchedule(game: GameInstance) -> Void {
  let tick: ref<RPCoreHudTick> = new RPCoreHudTick();
  tick.game = game;
  tick.controller = this;
  tick.generation = this.m_rpcGeneration;
  // false: real time, so the bars still update during slow motion.
  GameInstance.GetDelaySystem(game).DelayCallback(tick, RPCoreHudPumpSeconds(), false);
}

@addMethod(healthbarWidgetGameController)
public func RPCoreTick(game: GameInstance, generation: Int32) -> Void {
  let system: ref<RPCoreHudSystem> = GameInstance.GetScriptableSystemsContainer(game).Get(n"RPCoreHudSystem") as RPCoreHudSystem;
  if !IsDefined(system) || system.generation != generation { return; }
  system.tickCounter += 1;
  this.RPCorePump(game, system);
  this.RPCoreTestStep(system);
  this.RPCoreSchedule(game);          // unconditional: one failure must not end the loop
}

@addMethod(healthbarWidgetGameController)
private func RPCoreComposeLabel(system: ref<RPCoreHudSystem>, bar: ref<RPCoreBarState>) -> String {
  if Equals(bar.id, "psychosis") && bar.tier >= 1 && bar.tier <= ArraySize(system.labels) && StrLen(system.labels[bar.tier - 1]) > 0 {
    return bar.label + " / " + StrUpper(system.labels[bar.tier - 1]);
  }
  return bar.label;
}

// Turn changed server state into events. Only what changed since this controller last looked.
@addMethod(healthbarWidgetGameController)
private func RPCorePump(game: GameInstance, system: ref<RPCoreHudSystem>) -> Void {
  if system.revision == this.m_rpcSeen && system.resetRev == this.m_rpcSeenReset { return; }
  if system.resetRev != this.m_rpcSeenReset {
    this.m_rpcSeenReset = system.resetRev;
    RPCoreHudDispatch(game, new RPCoreHudResetEvent());
  }
  let i: Int32 = 0;
  while i < ArraySize(system.bars) {
    let bar: ref<RPCoreBarState> = system.bars[i];
    if bar.removed {
      let gone: ref<RPCoreBarRemoveEvent> = new RPCoreBarRemoveEvent();
      gone.id = bar.id;
      RPCoreHudDispatch(game, gone);
      ArrayErase(system.bars, i);
      continue;
    }
    if bar.defRev > this.m_rpcSeen {
      let def: ref<RPCoreBarDefineEvent> = new RPCoreBarDefineEvent();
      def.id = bar.id;
      def.label = bar.label;
      def.order = bar.order;
      def.color = bar.color;
      def.ticks = bar.ticks;
      RPCoreHudDispatch(game, def);
    }
    if bar.valRev > this.m_rpcSeen && !system.cleared {
      let val: ref<RPCoreBarValueEvent> = new RPCoreBarValueEvent();
      val.id = bar.id;
      val.label = this.RPCoreComposeLabel(system, bar);
      val.visible = bar.visible;
      val.value = bar.value;
      val.maxValue = bar.maxValue;
      val.tier = bar.tier;
      RPCoreHudDispatch(game, val);
    }
    i += 1;
  }
  this.m_rpcSeen = system.revision;
}
