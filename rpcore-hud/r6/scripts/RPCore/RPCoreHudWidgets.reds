// RPCore native HUD -- widget spawning, style probe and the host that owns the bars.
//
// SPAWN LADDER (first rung that yields a widget wins), per bar:
//   1. SpawnFromLocal(container, libraryId)     the vanilla procedure: a library item inside
//                                               the HUD controller's own .inkwidget.
//   2. SpawnFromExternal(container, resource)   a WolvenKit-authored .inkwidget (archive mod).
//   3. Procedural clone                         built from the vanilla stamina/oxygen atlas parts,
//                                               geometry measured from the live vanilla health bar.
// Rungs 1-2 are off until their knobs in RPCoreHudConfig.reds are set; rung 3 always works.
// Templates for rungs 1-2 are adopted by child NAME: "fill" (scaled 0..1), "label", "value".

// Public helpers on the base HUD class so any HUD controller can host bars. They live on
// inkHUDGameController because spawning is a method of the controller that owns the widget.
@addMethod(inkHUDGameController)
public func RPCoreSpawnLocal(parent: ref<inkWidget>, libraryId: CName) -> wref<inkWidget> {
  return this.SpawnFromLocal(parent, libraryId);
}

@addMethod(inkHUDGameController)
public func RPCoreSpawnExternal(parent: ref<inkWidget>, libraryId: CName) -> wref<inkWidget> {
  // Point this at your own resource when RPCoreHudExternalEnabled() is true.
  return this.SpawnFromExternal(parent, r"rpcore\\gui\\rpcore_bar.inkwidget", libraryId);
}

public class RPCoreStyleProbe extends IScriptable {
  public let anchor: inkEAnchor;
  public let anchorPoint: Vector2;
  public let margin: inkMargin;
  public let size: Vector2;
  public let scale: Vector2;
  public let bottomAnchored: Bool;
}

// Measure the vanilla bar so the container inherits its anchor, margin, size and scale.
public static func RPCoreProbeStyle(root: ref<inkWidget>) -> ref<RPCoreStyleProbe> {
  let probe: ref<RPCoreStyleProbe> = new RPCoreStyleProbe();
  probe.anchor = root.GetAnchor();
  probe.anchorPoint = root.GetAnchorPoint();
  probe.margin = root.GetMargin();
  probe.size = root.GetSize();
  probe.scale = root.GetScale();
  if probe.size.Y < 10.0 { probe.size.Y = RPCoreHudFallbackRootHeight(); }
  probe.bottomAnchored = Equals(probe.anchor, inkEAnchor.BottomLeft)
    || Equals(probe.anchor, inkEAnchor.BottomCenter)
    || Equals(probe.anchor, inkEAnchor.BottomRight);
  return probe;
}

public class RPCoreBar extends IScriptable {
  public let id: String;
  public let root: ref<inkWidget>;
  public let label: ref<inkText>;
  public let valueText: ref<inkText>;
  public let fill: ref<inkWidget>;
  public let ticks: array<ref<inkWidget>>;
  public let procedural: Bool;
  public let shown: Bool;
  public let order: Int32;
  public let tier: Int32;
  public let width: Float;
}

// Vanilla atlas art; falls back to a flat rectangle if the part is missing so the bar never vanishes.
public static func RPCoreMakeArt(parent: ref<inkCompoundWidget>, name: CName, part: CName) -> ref<inkWidget> {
  let img: ref<inkImage> = parent.AddChild(n"inkImageWidget") as inkImage;
  img.SetName(name);
  img.SetAtlasResource(r"base\\gameplay\\gui\\common\\stamina_oxygen_bar\\stamina_oxygen_bar.inkatlas");
  img.SetTexturePart(part);
  if !img.IsTexturePartExist(part) {
    parent.RemoveChild(img);
    let rect: ref<inkRectangle> = parent.AddChild(n"inkRectangleWidget") as inkRectangle;
    rect.SetName(name);
    return rect;
  }
  return img;
}

public static func RPCoreMakeText(parent: ref<inkCompoundWidget>, name: CName, size: Int32, anchor: inkEAnchor) -> ref<inkText> {
  let text: ref<inkText> = parent.AddChild(n"inkTextWidget") as inkText;
  text.SetName(name);
  text.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily", n"Medium");
  text.SetFontSize(size);
  text.SetLetterCase(textLetterCase.UpperCase);
  text.SetAnchor(anchor);
  text.SetMargin(0.0, 0.0, 0.0, 0.0);
  text.SetTintColor(new HDRColor(0.92, 0.96, 0.98, 0.95));
  text.SetText("");
  return text;
}

// Rung 3: procedural clone.
public static func RPCoreBuildProcedural(container: ref<inkCompoundWidget>, id: String) -> ref<RPCoreBar> {
  let width: Float = RPCoreHudBarWidth();
  let thickness: Float = RPCoreHudBarThickness();
  let bar: ref<RPCoreBar> = new RPCoreBar();
  bar.id = id;
  bar.procedural = true;
  bar.width = width;

  let root: ref<inkCanvas> = container.AddChild(n"inkCanvasWidget") as inkCanvas;
  root.SetName(StringToName("RPCoreBar_" + id));
  root.SetAnchor(inkEAnchor.TopLeft);
  root.SetAnchorPoint(new Vector2(0.0, 0.0));
  root.SetSize(width, RPCoreHudBlockHeight());
  root.SetInteractive(false);
  root.SetVisible(false);
  bar.root = root;

  bar.label = RPCoreMakeText(root, n"label", 16, inkEAnchor.TopLeft);
  bar.valueText = RPCoreMakeText(root, n"value", 16, inkEAnchor.TopRight);

  let back: ref<inkRectangle> = root.AddChild(n"inkRectangleWidget") as inkRectangle;
  back.SetName(n"background");
  back.SetAnchor(inkEAnchor.TopLeft);
  back.SetMargin(0.0, 20.0, 0.0, 0.0);
  back.SetSize(width, thickness);
  back.SetTintColor(new HDRColor(0.025, 0.045, 0.06, 0.6));

  let frame: ref<inkWidget> = RPCoreMakeArt(root, n"frame", n"bar_stroke");
  frame.SetAnchor(inkEAnchor.TopLeft);
  frame.SetMargin(0.0, 20.0, 0.0, 0.0);
  frame.SetSize(width, thickness);
  frame.SetTintColor(new HDRColor(0.37, 0.96, 1.0, 0.45));

  let fill: ref<inkWidget> = RPCoreMakeArt(root, n"fill", n"bar");
  fill.SetAnchor(inkEAnchor.TopLeft);
  fill.SetMargin(0.0, 20.0, 0.0, 0.0);
  fill.SetSize(width, thickness);
  fill.SetRenderTransformPivot(0.0, 0.5);        // scale from the left edge
  fill.SetScale(new Vector2(0.0, 1.0));
  bar.fill = fill;
  return bar;
}

// Rungs 1-2: adopt a spawned template by child name.
public static func RPCoreAdoptTemplate(spawned: ref<inkWidget>, id: String) -> ref<RPCoreBar> {
  let bar: ref<RPCoreBar> = new RPCoreBar();
  bar.id = id;
  bar.root = spawned;
  bar.width = spawned.GetWidth();
  spawned.SetName(StringToName("RPCoreBar_" + id));
  spawned.SetVisible(false);
  let compound: ref<inkCompoundWidget> = spawned as inkCompoundWidget;
  if IsDefined(compound) {
    bar.fill = compound.GetWidget(n"fill");
    bar.label = compound.GetWidget(n"label") as inkText;
    bar.valueText = compound.GetWidget(n"value") as inkText;
  }
  return bar;
}

public class RPCoreHudHost extends IScriptable {
  public let owner: wref<inkHUDGameController>;
  public let container: ref<inkCanvas>;
  public let probe: ref<RPCoreStyleProbe>;
  public let bars: array<ref<RPCoreBar>>;

  public func IsMounted() -> Bool {
    return IsDefined(this.container);
  }

  // Container is a SIBLING of the vanilla bar (same parent, same anchor, stacked past it) so the
  // vanilla bar being hidden or faded does not take ours with it, and HUD scaling still applies.
  public func Mount(owner: ref<inkHUDGameController>) -> Bool {
    if this.IsMounted() { return true; }
    let root: ref<inkWidget> = owner.GetRootWidget();
    if !IsDefined(root) { return false; }
    this.owner = owner;
    this.probe = RPCoreProbeStyle(root);

    let parent: ref<inkCompoundWidget> = root.parentWidget as inkCompoundWidget;
    let asChild: Bool = false;
    if !IsDefined(parent) {
      parent = owner.GetRootCompoundWidget();
      asChild = true;
    }
    if !IsDefined(parent) { return false; }

    this.container = parent.AddChild(n"inkCanvasWidget") as inkCanvas;
    this.container.SetName(n"RPCoreVitals");
    this.container.SetInteractive(false);
    this.container.SetVisible(false);
    this.container.SetSize(RPCoreHudBarWidth(), RPCoreHudBlockHeight() * Cast<Float>(RPCoreHudMaxBars()));
    this.container.SetScale(this.probe.scale);

    let step: Float = this.probe.size.Y + RPCoreHudGap();
    if asChild {
      this.container.SetAnchor(inkEAnchor.TopLeft);
      this.container.SetAnchorPoint(new Vector2(0.0, 0.0));
      this.container.SetMargin(RPCoreHudOffsetX(), step, 0.0, 0.0);
    } else {
      let margin: inkMargin = this.probe.margin;
      this.container.SetAnchor(this.probe.anchor);
      this.container.SetAnchorPoint(this.probe.anchorPoint);
      if this.probe.bottomAnchored { margin.bottom += step; } else { margin.top += step; }
      margin.left += RPCoreHudOffsetX();
      this.container.SetMargin(margin);
    }
    return true;
  }

  public func Find(id: String) -> ref<RPCoreBar> {
    let i: Int32 = 0;
    while i < ArraySize(this.bars) {
      if Equals(this.bars[i].id, id) { return this.bars[i]; }
      i += 1;
    }
    return null;
  }

  private func Spawn(id: String) -> ref<RPCoreBar> {
    let localId: String = RPCoreHudSpawnLocalId();
    if StrLen(localId) > 0 {
      let fromLocal: wref<inkWidget> = this.owner.RPCoreSpawnLocal(this.container, StringToName(localId));
      if IsDefined(fromLocal) { return RPCoreAdoptTemplate(fromLocal, id); }
    }
    if RPCoreHudExternalEnabled() {
      let fromExternal: wref<inkWidget> = this.owner.RPCoreSpawnExternal(this.container, n"Root");
      if IsDefined(fromExternal) { return RPCoreAdoptTemplate(fromExternal, id); }
    }
    return RPCoreBuildProcedural(this.container, id);
  }

  private func SetTicks(bar: ref<RPCoreBar>, fractions: array<Float>) -> Void {
    if !bar.procedural { return; }
    let root: ref<inkCompoundWidget> = bar.root as inkCompoundWidget;
    while ArraySize(bar.ticks) < ArraySize(fractions) {
      let mark: ref<inkWidget> = RPCoreMakeArt(root, n"tick", n"bar_marker");
      mark.SetAnchor(inkEAnchor.TopLeft);
      mark.SetSize(6.0, RPCoreHudBarThickness() + 4.0);
      mark.SetTintColor(new HDRColor(1.0, 1.0, 1.0, 0.85));
      mark.SetVisible(false);
      ArrayPush(bar.ticks, mark);
    }
    let i: Int32 = 0;
    while i < ArraySize(bar.ticks) {
      if i < ArraySize(fractions) {
        bar.ticks[i].SetMargin(bar.width * fractions[i] - 3.0, 18.0, 0.0, 0.0);
        bar.ticks[i].SetVisible(true);
      } else {
        bar.ticks[i].SetVisible(false);
      }
      i += 1;
    }
  }

  public func Define(evt: ref<RPCoreBarDefineEvent>) -> Void {
    if !this.IsMounted() { return; }
    let bar: ref<RPCoreBar> = this.Find(evt.id);
    if !IsDefined(bar) {
      if ArraySize(this.bars) >= RPCoreHudMaxBars() { return; }
      bar = this.Spawn(evt.id);
      if !IsDefined(bar) { return; }
      ArrayPush(this.bars, bar);
    }
    bar.order = evt.order;
    if IsDefined(bar.label) { bar.label.SetText(evt.label); }
    if IsDefined(bar.fill) { bar.fill.SetTintColor(evt.color); }
    this.SetTicks(bar, evt.ticks);
    this.Relayout();
  }

  public func Apply(evt: ref<RPCoreBarValueEvent>) -> Void {
    let bar: ref<RPCoreBar> = this.Find(evt.id);
    if !IsDefined(bar) { return; }
    bar.shown = evt.visible;
    bar.root.SetVisible(evt.visible);
    if evt.visible {
      let fraction: Float = evt.maxValue > 0.0 ? ClampF(evt.value / evt.maxValue, 0.0, 1.0) : 0.0;
      if IsDefined(bar.fill) { bar.fill.SetScale(new Vector2(fraction, 1.0)); }
      if IsDefined(bar.label) { bar.label.SetText(evt.label); }
      if IsDefined(bar.valueText) { bar.valueText.SetText(IntToString(FloorF(evt.value))); }
      if Equals(evt.id, "psychosis") { this.ApplyTier(bar, evt.tier); }
    }
    this.Relayout();
  }

  // Strained+ : red tint and a flicker on the bar; harder flicker from Fraying.
  private func ApplyTier(bar: ref<RPCoreBar>, tier: Int32) -> Void {
    if IsDefined(bar.fill) { bar.fill.SetTintColor(RPCoreHudColorPsychosis(tier)); }
    if tier == bar.tier { return; }
    bar.tier = tier;
    bar.root.StopAllAnimations();
    bar.root.SetOpacity(1.0);
    if tier < 2 { return; }
    let def: ref<inkAnimDef> = new inkAnimDef();
    let flicker: ref<inkAnimTransparency> = new inkAnimTransparency();
    flicker.SetStartTransparency(1.0);
    flicker.SetEndTransparency(tier >= 3 ? 0.5 : 0.7);
    flicker.SetDuration(tier >= 3 ? 0.14 : 0.3);
    flicker.SetType(inkanimInterpolationType.Linear);
    flicker.SetMode(inkanimInterpolationMode.EasyInOut);
    def.AddInterpolator(flicker);
    bar.root.PlayAnimationWithOptions(def, GetAnimOptionsInfiniteLoop(inkanimLoopType.PingPong));
  }

  public func Remove(evt: ref<RPCoreBarRemoveEvent>) -> Void {
    let bar: ref<RPCoreBar> = this.Find(evt.id);
    if !IsDefined(bar) { return; }
    this.container.RemoveChild(bar.root);
    ArrayRemove(this.bars, bar);
    this.Relayout();
  }

  public func Reset() -> Void {
    let i: Int32 = 0;
    while i < ArraySize(this.bars) {
      this.bars[i].shown = false;
      this.bars[i].root.SetVisible(false);
      i += 1;
    }
    if this.IsMounted() { this.container.SetVisible(false); }
  }

  // Stack visible bars in `order`, no gaps; show the container only if something is visible.
  public func Relayout() -> Void {
    let placed: array<Bool>;
    let i: Int32 = 0;
    while i < ArraySize(this.bars) { ArrayPush(placed, false); i += 1; }
    let y: Float = 0.0;
    let any: Bool = false;
    let n: Int32 = 0;
    while n < ArraySize(this.bars) {
      let pick: Int32 = -1;
      i = 0;
      while i < ArraySize(this.bars) {
        if !placed[i] && (pick < 0 || this.bars[i].order < this.bars[pick].order) { pick = i; }
        i += 1;
      }
      if pick < 0 { break; }
      placed[pick] = true;
      if this.bars[pick].shown {
        this.bars[pick].root.SetMargin(0.0, y, 0.0, 0.0);
        y += RPCoreHudBlockHeight();
        any = true;
      }
      n += 1;
    }
    this.container.SetVisible(any);
  }
}
