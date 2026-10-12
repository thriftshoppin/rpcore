// RPCore native HUD -- typed events.
//
// Same transport Open77 uses for its HUD policy: GameInstance.GetUISystem(game).QueueEvent(evt)
// reaches every HUD controller that declares `cb func On<EventName>(evt)`. Anything
// script-side (not just the Lua bridge) can drive the HUD by queueing one of these.

public class RPCoreBarDefineEvent extends Event {
  public let id: String;
  public let label: String;
  public let order: Int32;
  public let color: HDRColor;
  public let ticks: array<Float>;   // fractions 0..1 where tier markers are drawn
}

public class RPCoreBarValueEvent extends Event {
  public let id: String;
  public let label: String;         // already composed (psychosis adds the tier name)
  public let visible: Bool;
  public let value: Float;
  public let maxValue: Float;
  public let tier: Int32;           // 1..5, only meaningful for the psychosis bar
}

public class RPCoreBarRemoveEvent extends Event {
  public let id: String;
}

public class RPCoreHudResetEvent extends Event {
}

// Script-side convenience: queue any RPCore event onto the HUD.
public static func RPCoreHudDispatch(game: GameInstance, evt: ref<Event>) -> Bool {
  let ui: ref<UISystem> = GameInstance.GetUISystem(game);
  if !IsDefined(ui) || !IsDefined(evt) { return false; }
  ui.QueueEvent(evt);
  return true;
}
