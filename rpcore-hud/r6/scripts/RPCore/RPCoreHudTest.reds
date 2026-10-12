// RPCore native HUD -- widget walk test.
//
// Walks EVERY ink widget in the live HUD tree (from the topmost ancestor of the health bar
// down) one at a time and prints test text into it, to prove the HUD call path end to end.
//   - inkText widget : its text is replaced with "RPC TEST i/N <path>", forced visible.
//   - any other widget : a temporary inkText label is added to it (or to its parent if it is
//     a leaf) reading "RPC TEST i/N <class> <name>".
// Each step undoes the previous one, so stopping leaves the HUD as it was. A text widget that
// used a localisation key gets its resolved text back, not the key. Run on a TEST client.
//
// Commands (via RPCoreHudTest(cmd) / the Lua /rpcore.hud.test command):
//   start   snapshot the tree and begin, advancing every RPCoreHudTestTicksPerStep() ticks
//   next | prev   pause auto-advance and step manually
//   stop    restore the last widget and end
//   status  report only        demo   push sample bar values through the normal ingress path

public class RPCoreWidgetTest extends IScriptable {
  public let active: Bool;
  public let autoRun: Bool;
  public let nodes: array<wref<inkWidget>>;
  public let paths: array<String>;
  public let index: Int32;
  public let ticksLeft: Int32;
  public let calls: Int32;
  public let failures: Int32;
  public let lastKind: String;

  // undo state for the widget currently being exercised
  public let touched: wref<inkWidget>;
  public let touchedText: Bool;
  public let savedText: String;
  public let savedVisible: Bool;
  public let savedOpacity: Float;
  public let tempParent: wref<inkCompoundWidget>;
  public let tempLabel: ref<inkText>;

  private func Walk(w: ref<inkWidget>, prefix: String, depth: Int32) -> Void {
    if !IsDefined(w) || depth > 14 || ArraySize(this.nodes) >= RPCoreHudTestMaxWidgets() { return; }
    let name: String = NameToString(w.GetName());
    let path: String = StrLen(prefix) > 0 ? prefix + "/" + name : name;
    ArrayPush(this.nodes, w);
    ArrayPush(this.paths, path);
    let compound: ref<inkCompoundWidget> = w as inkCompoundWidget;
    if IsDefined(compound) {
      let count: Int32 = compound.GetNumChildren();
      let i: Int32 = 0;
      while i < count {
        this.Walk(compound.GetWidgetByIndex(i), path, depth + 1);
        i += 1;
      }
    }
  }

  private func Restore() -> Void {
    if IsDefined(this.touched) {
      if this.touchedText {
        let text: ref<inkText> = this.touched as inkText;
        if IsDefined(text) { text.SetText(this.savedText); }
        this.touched.SetVisible(this.savedVisible);
        this.touched.SetOpacity(this.savedOpacity);
      }
    }
    if IsDefined(this.tempParent) && IsDefined(this.tempLabel) {
      this.tempParent.RemoveChild(this.tempLabel);
    }
    this.touched = null;
    this.touchedText = false;
    this.tempParent = null;
    this.tempLabel = null;
  }

  private func Show(i: Int32) -> Void {
    this.Restore();
    this.index = i;
    let total: Int32 = ArraySize(this.nodes);
    if i < 0 || i >= total { this.lastKind = "end"; return; }
    let w: wref<inkWidget> = this.nodes[i];
    if !IsDefined(w) { this.failures += 1; this.lastKind = "gone"; return; }
    let head: String = "RPC TEST " + IntToString(i + 1) + "/" + IntToString(total);
    this.calls += 1;

    let text: ref<inkText> = w as inkText;
    if IsDefined(text) {
      this.touched = w;
      this.touchedText = true;
      this.savedText = text.GetText();
      this.savedVisible = w.IsVisible();
      this.savedOpacity = w.GetOpacity();
      w.SetVisible(true);
      w.SetOpacity(1.0);
      text.SetText(head + " " + this.paths[i]);
      this.lastKind = "text";
      return;
    }

    let host: ref<inkCompoundWidget> = w as inkCompoundWidget;
    if !IsDefined(host) { host = w.parentWidget as inkCompoundWidget; }
    if !IsDefined(host) { this.failures += 1; this.lastKind = "no_host"; return; }
    let label: ref<inkText> = host.AddChild(n"inkTextWidget") as inkText;
    if !IsDefined(label) { this.failures += 1; this.lastKind = "add_failed"; return; }
    label.SetName(n"RPCoreTestLabel");
    label.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily", n"Medium");
    label.SetFontSize(14);
    label.SetAnchor(inkEAnchor.TopLeft);
    label.SetMargin(0.0, 0.0, 0.0, 0.0);
    label.SetTintColor(new HDRColor(1.5, 0.2, 1.5, 1.0));
    label.SetText(head + " " + NameToString(w.GetClassName()) + " " + NameToString(w.GetName()));
    this.tempParent = host;
    this.tempLabel = label;
    this.lastKind = "label";
  }

  public func Report() -> String {
    let total: Int32 = ArraySize(this.nodes);
    let path: String = this.index >= 0 && this.index < total ? this.paths[this.index] : "-";
    return "test=" + (this.active ? "running" : "idle")
      + ";step=" + IntToString(this.index + 1) + "/" + IntToString(total)
      + ";kind=" + this.lastKind
      + ";calls=" + IntToString(this.calls)
      + ";fail=" + IntToString(this.failures)
      + ";path=" + path;
  }

  public func Command(command: String, root: ref<inkWidget>) -> Void {
    if Equals(command, "start") {
      this.Restore();
      ArrayClear(this.nodes);
      ArrayClear(this.paths);
      this.calls = 0;
      this.failures = 0;
      let top: ref<inkWidget> = root;
      let guard: Int32 = 0;
      while IsDefined(top.parentWidget) && guard < 16 {
        top = top.parentWidget;
        guard += 1;
      }
      this.Walk(top, "", 0);
      this.active = true;
      this.autoRun = true;
      this.ticksLeft = RPCoreHudTestTicksPerStep();
      this.Show(0);
    } else if Equals(command, "next") && this.active {
      this.autoRun = false;
      this.Show(this.index + 1);
    } else if Equals(command, "prev") && this.active {
      this.autoRun = false;
      this.Show(this.index - 1);
    } else if Equals(command, "stop") {
      this.Restore();
      this.active = false;
      this.lastKind = "stopped";
    }
  }

  // Called every pump tick; advances automatically while running.
  public func Tick() -> Void {
    if !this.active || !this.autoRun { return; }
    this.ticksLeft -= 1;
    if this.ticksLeft > 0 { return; }
    this.ticksLeft = RPCoreHudTestTicksPerStep();
    if this.index + 1 >= ArraySize(this.nodes) {
      this.Restore();
      this.active = false;
      this.lastKind = "done";
      return;
    }
    this.Show(this.index + 1);
  }
}

@addMethod(healthbarWidgetGameController)
private func RPCoreTestStep(system: ref<RPCoreHudSystem>) -> Void {
  if !IsDefined(this.m_rpcTest) { this.m_rpcTest = new RPCoreWidgetTest(); }
  if StrLen(system.testCommand) > 0 {
    let command: String = system.testCommand;
    system.testCommand = "";
    this.m_rpcTest.Command(command, this.GetRootWidget());
  } else {
    this.m_rpcTest.Tick();
  }
  if this.m_rpcTest.active || StrLen(system.testReport) > 0 {
    system.testReport = this.m_rpcTest.Report();
    if this.m_rpcTest.active { LogChannel(n"RPCore", system.testReport); }
  }
}
