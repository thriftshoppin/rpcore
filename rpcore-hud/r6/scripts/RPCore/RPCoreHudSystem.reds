// RPCore native HUD -- server-state store and the entry points Lua / EventCore call.
//
// INGRESS RULE: functions at the bottom are called from Lua through Open77.rtti.call (a
// native -> script call). They only validate and STORE. They never touch a widget. The HUD
// controller's own pump (RPCoreHudController.reds) later turns stored state into events and
// the cb handlers mutate widgets, always on the game's UI frame. (Open77's ScriptBridge
// documents that native code must not run scripted logic without a script frame.)
//
// Legacy entry points (RPCoreHudPing/Configure/SetBar/SetPsychosis/Heartbeat/Clear/Status)
// keep their old signatures, so client/native_hud.lua works unchanged.

public class RPCoreBarState extends IScriptable {
  public let id: String;
  public let label: String;
  public let order: Int32;
  public let color: HDRColor;
  public let ticks: array<Float>;
  public let visible: Bool;
  public let value: Float;
  public let maxValue: Float;
  public let tier: Int32;
  public let defRev: Int32;    // system.revision when the definition last changed
  public let valRev: Int32;    // system.revision when the value last changed
  public let removed: Bool;
}

public class RPCoreHudSystem extends ScriptableSystem {
  public let bars: array<ref<RPCoreBarState>>;
  public let revision: Int32;
  public let resetRev: Int32;
  public let cleared: Bool;
  public let attached: Bool;
  public let generation: Int32;     // newest controller owns the pump
  public let tickCounter: Int32;
  public let lastPushTick: Int32;
  public let bounds: array<Float>;  // psychosis tier boundaries (fractions of max)
  public let labels: array<String>; // psychosis tier names
  public let psyLabel: String;
  public let testCommand: String;   // pending widget-test command for the controller
  public let testReport: String;    // latest widget-test report
}

public static func RPCoreHudSystemGet() -> ref<RPCoreHudSystem> {
  return GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"RPCoreHudSystem") as RPCoreHudSystem;
}

// ---- parsing helpers --------------------------------------------------------------------
public static func RPCoreParseFloats(csv: String) -> array<Float> {
  let out: array<Float>;
  if StrLen(csv) == 0 { return out; }
  let parts: array<String> = StrSplit(csv, ",");
  let i: Int32 = 0;
  while i < ArraySize(parts) {
    ArrayPush(out, StringToFloat(parts[i]));
    i += 1;
  }
  return out;
}

// "r,g,b,a" (HDR floats, a optional) -> color; fallback on anything malformed.
public static func RPCoreParseColor(csv: String, fallback: HDRColor) -> HDRColor {
  let f: array<Float> = RPCoreParseFloats(csv);
  if ArraySize(f) < 3 { return fallback; }
  return new HDRColor(f[0], f[1], f[2], ArraySize(f) >= 4 ? f[3] : 1.0);
}

// Payload format "k=v;k=v". Servers must not put ';' or '=' inside values.
public static func RPCoreKv(payload: String, key: String, fallback: String) -> String {
  let parts: array<String> = StrSplit(payload, ";");
  let i: Int32 = 0;
  while i < ArraySize(parts) {
    let kv: array<String> = StrSplit(parts[i], "=");
    if ArraySize(kv) >= 2 && Equals(kv[0], key) { return kv[1]; }
    i += 1;
  }
  return fallback;
}

public static func RPCoreCleanId(id: String) -> String {
  if StrLen(id) < 1 || StrLen(id) > 32 { return ""; }
  return id;
}

public static func RPCoreDefaultColor(id: String) -> HDRColor {
  if Equals(id, "hunger") { return RPCoreHudColorHunger(); }
  if Equals(id, "thirst") { return RPCoreHudColorThirst(); }
  if Equals(id, "psychosis") { return RPCoreHudColorPsychosis(1); }
  return RPCoreHudColorGeneric();
}

// ---- registry ---------------------------------------------------------------------------
private static func RPCoreTouchDef(system: ref<RPCoreHudSystem>, bar: ref<RPCoreBarState>) -> Void {
  system.revision += 1;
  bar.defRev = system.revision;
  system.lastPushTick = system.tickCounter;
}

private static func RPCoreTouchVal(system: ref<RPCoreHudSystem>, bar: ref<RPCoreBarState>) -> Void {
  system.revision += 1;
  bar.valRev = system.revision;
  system.lastPushTick = system.tickCounter;
}

public static func RPCoreBarFor(system: ref<RPCoreHudSystem>, id: String, create: Bool) -> ref<RPCoreBarState> {
  let i: Int32 = 0;
  while i < ArraySize(system.bars) {
    if Equals(system.bars[i].id, id) && !system.bars[i].removed { return system.bars[i]; }
    i += 1;
  }
  if !create || ArraySize(system.bars) >= RPCoreHudMaxBars() { return null; }
  let bar: ref<RPCoreBarState> = new RPCoreBarState();
  bar.id = id;
  bar.label = StrUpper(id);
  bar.order = ArraySize(system.bars);
  bar.color = RPCoreDefaultColor(id);
  bar.maxValue = 100.0;
  bar.tier = 1;
  ArrayPush(system.bars, bar);
  RPCoreTouchDef(system, bar);
  return bar;
}

// ---- ingress: legacy signatures ---------------------------------------------------------
public static func RPCoreHudPing() -> Bool {
  return IsDefined(RPCoreHudSystemGet());
}

public static func RPCoreHudConfigure(
  bounds: String, labels: String, relicEnabled: Bool, relicRecord: String,
  fxName: String, psychosisLabel: String, hungerLabel: String, thirstLabel: String
) -> Bool {
  let system: ref<RPCoreHudSystem> = RPCoreHudSystemGet();
  if !IsDefined(system) { return false; }
  system.bounds = RPCoreParseFloats(bounds);
  ArrayClear(system.labels);
  if StrLen(labels) > 0 { system.labels = StrSplit(labels, ","); }
  system.psyLabel = StrLen(psychosisLabel) > 0 ? psychosisLabel : "CYBERPSYCHOSIS";

  let hunger: ref<RPCoreBarState> = RPCoreBarFor(system, "hunger", true);
  let thirst: ref<RPCoreBarState> = RPCoreBarFor(system, "thirst", true);
  let psy: ref<RPCoreBarState> = RPCoreBarFor(system, "psychosis", true);
  if !IsDefined(hunger) || !IsDefined(thirst) || !IsDefined(psy) { return false; }
  hunger.order = 0; hunger.label = StrLen(hungerLabel) > 0 ? hungerLabel : "HUNGER";
  thirst.order = 1; thirst.label = StrLen(thirstLabel) > 0 ? thirstLabel : "THIRST";
  psy.order = 2;    psy.label = system.psyLabel;
  psy.ticks = system.bounds;
  RPCoreTouchDef(system, hunger);
  RPCoreTouchDef(system, thirst);
  RPCoreTouchDef(system, psy);
  // relicEnabled / relicRecord / fxName are accepted for signature compatibility only:
  // the status-effect and Blackwall behaviour of the first pack is not part of this one.
  return true;
}

// Any bar id works now, not just hunger / thirst.
public static func RPCoreHudSetBar(bar: String, visible: Bool, value: Float, max: Float) -> Bool {
  let system: ref<RPCoreHudSystem> = RPCoreHudSystemGet();
  let id: String = RPCoreCleanId(bar);
  if !IsDefined(system) || StrLen(id) == 0 || max <= 0.0 { return false; }
  let state: ref<RPCoreBarState> = RPCoreBarFor(system, id, true);
  if !IsDefined(state) { return false; }
  state.visible = visible;
  state.value = ClampF(value, 0.0, max);
  state.maxValue = max;
  system.cleared = false;
  RPCoreTouchVal(system, state);
  return true;
}

public static func RPCoreHudSetPsychosis(visible: Bool, value: Float, max: Float, tier: Int32) -> Bool {
  let system: ref<RPCoreHudSystem> = RPCoreHudSystemGet();
  if !IsDefined(system) || max <= 0.0 { return false; }
  let state: ref<RPCoreBarState> = RPCoreBarFor(system, "psychosis", true);
  if !IsDefined(state) { return false; }
  state.visible = visible;
  state.value = ClampF(value, 0.0, max);
  state.maxValue = max;
  state.tier = tier < 1 ? 1 : (tier > 5 ? 5 : tier);
  system.cleared = false;
  RPCoreTouchVal(system, state);
  return true;
}

public static func RPCoreHudHeartbeat() -> Bool {
  let system: ref<RPCoreHudSystem> = RPCoreHudSystemGet();
  if !IsDefined(system) { return false; }
  system.lastPushTick = system.tickCounter;
  return true;
}

public static func RPCoreHudClear() -> Bool {
  let system: ref<RPCoreHudSystem> = RPCoreHudSystemGet();
  if !IsDefined(system) { return false; }
  let i: Int32 = 0;
  while i < ArraySize(system.bars) {
    system.bars[i].visible = false;
    i += 1;
  }
  system.cleared = true;
  system.revision += 1;
  system.resetRev = system.revision;
  return true;
}

// ---- ingress: new, server-driven -------------------------------------------------------
// Declare (or redefine) a bar at runtime. color = "r,g,b,a" HDR floats; ticks = "0.25,0.5".
public static func RPCoreHudDefineBar(id: String, label: String, color: String, order: Int32, ticks: String) -> Bool {
  let system: ref<RPCoreHudSystem> = RPCoreHudSystemGet();
  let clean: String = RPCoreCleanId(id);
  if !IsDefined(system) || StrLen(clean) == 0 { return false; }
  let state: ref<RPCoreBarState> = RPCoreBarFor(system, clean, true);
  if !IsDefined(state) { return false; }
  if StrLen(label) > 0 { state.label = label; }
  state.color = RPCoreParseColor(color, state.color);
  state.order = order;
  state.ticks = RPCoreParseFloats(ticks);
  RPCoreTouchDef(system, state);
  return true;
}

public static func RPCoreHudRemoveBar(id: String) -> Bool {
  let system: ref<RPCoreHudSystem> = RPCoreHudSystemGet();
  if !IsDefined(system) { return false; }
  let state: ref<RPCoreBarState> = RPCoreBarFor(system, id, false);
  if !IsDefined(state) { return false; }
  state.removed = true;
  system.revision += 1;
  return true;
}

// One-call envelope for EventCore: channel + "k=v;k=v".
//   bar    id=thirst;v=61;max=100;show=1
//   define id=energy;label=ENERGY;color=0.4,1.1,0.4,1;order=3;ticks=0.25,0.5
//   remove id=energy
//   clear
public static func RPCoreHudPush(channel: String, payload: String) -> Bool {
  if Equals(channel, "bar") {
    return RPCoreHudSetBar(
      RPCoreKv(payload, "id", ""),
      !Equals(RPCoreKv(payload, "show", "1"), "0"),
      StringToFloat(RPCoreKv(payload, "v", "0")),
      StringToFloat(RPCoreKv(payload, "max", "100")));
  }
  if Equals(channel, "define") {
    return RPCoreHudDefineBar(
      RPCoreKv(payload, "id", ""), RPCoreKv(payload, "label", ""), RPCoreKv(payload, "color", ""),
      StringToInt(RPCoreKv(payload, "order", "50")), RPCoreKv(payload, "ticks", ""));
  }
  if Equals(channel, "remove") { return RPCoreHudRemoveBar(RPCoreKv(payload, "id", "")); }
  if Equals(channel, "clear") { return RPCoreHudClear(); }
  return false;
}

// "k=v;k=v" for Lua to log.
public static func RPCoreHudStatus() -> String {
  let system: ref<RPCoreHudSystem> = RPCoreHudSystemGet();
  if !IsDefined(system) { return "attached=0;system=unreachable"; }
  let stale: Bool = system.revision > 0 && system.tickCounter - system.lastPushTick > 150;
  return "attached=" + (system.attached ? "1" : "0")
    + ";bars=" + IntToString(ArraySize(system.bars))
    + ";stale=" + (stale ? "1" : "0")
    + ";rev=" + IntToString(system.revision);
}

// Widget walk test + demo values. Commands: start | stop | next | prev | status | demo.
// The walk runs on the controller pump; this returns the latest report.
public static func RPCoreHudTest(command: String) -> String {
  let system: ref<RPCoreHudSystem> = RPCoreHudSystemGet();
  if !IsDefined(system) { return "test=unreachable"; }
  if Equals(command, "demo") {
    RPCoreHudDefineBar("energy", "ENERGY", "0.4,1.1,0.4,1.0", 3, "0.25,0.5,0.75");
    RPCoreHudSetBar("hunger", true, 74.0, 100.0);
    RPCoreHudSetBar("thirst", true, 61.0, 100.0);
    RPCoreHudSetBar("energy", true, 40.0, 100.0);
    RPCoreHudSetPsychosis(true, 62.0, 100.0, 3);
    return "demo=ok";
  }
  system.testCommand = command;
  return StrLen(system.testReport) > 0 ? system.testReport : "test=queued";
}
