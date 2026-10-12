// RPCore native HUD -- layout / style knobs.
//
// Everything here is drawn by the game's own ink HUD. No WebUI, no HTML, no overlay.
// redscript has no constants, so knobs are functions. Tune here, nothing else.
//
// ART: bars reuse the vanilla stamina/oxygen bar atlas
//   base\gameplay\gui\common\stamina_oxygen_bar\stamina_oxygen_bar.inkatlas
//   parts: bar (700x15 fill), bar_stroke (700x15 frame), bar_marker (13x15 tick)
// (read from the .inkatlas exports in fonts.zip), so new bars use the same texture as vanilla.

public static func RPCoreHudBarWidth() -> Float { return 260.0; }
public static func RPCoreHudBarThickness() -> Float { return 8.0; }
public static func RPCoreHudBlockHeight() -> Float { return 30.0; }
public static func RPCoreHudGap() -> Float { return 14.0; }
public static func RPCoreHudOffsetX() -> Float { return 0.0; }
public static func RPCoreHudFallbackRootHeight() -> Float { return 60.0; }
public static func RPCoreHudMaxBars() -> Int32 { return 8; }
// Controller pump: moves server state onto the HUD this often (real time, not game time).
public static func RPCoreHudPumpSeconds() -> Float { return 0.1; }

// Spawn ladder (see RPCoreHudWidgets.reds). Empty / false = skip that rung.
// RPCoreHudSpawnLocalId: a library item in the HUD controller's OWN .inkwidget (SpawnFromLocal).
//   The vanilla library item names are not in the uploads, so this ships empty.
// RPCoreHudExternalEnabled: SpawnFromExternal of a WolvenKit-authored .inkwidget (archive mod).
public static func RPCoreHudSpawnLocalId() -> String { return ""; }
public static func RPCoreHudExternalEnabled() -> Bool { return false; }

public static func RPCoreHudColorHunger() -> HDRColor { return new HDRColor(1.2, 0.8, 0.25, 1.0); }
public static func RPCoreHudColorThirst() -> HDRColor { return new HDRColor(0.368, 0.964, 1.0, 1.0); }
public static func RPCoreHudColorGeneric() -> HDRColor { return new HDRColor(0.6, 1.1, 0.6, 1.0); }
public static func RPCoreHudColorPsychosis(tier: Int32) -> HDRColor {
  if tier >= 4 { return new HDRColor(1.5, 0.1, 0.1, 1.0); }
  if tier >= 2 { return new HDRColor(1.4, 0.2, 0.15, 1.0); }
  return new HDRColor(1.1761, 0.3809, 0.3476, 1.0);
}

// Widget test command (RPCoreHudTest.reds).
public static func RPCoreHudTestTicksPerStep() -> Int32 { return 8; }     // 8 x 0.1 s per widget
public static func RPCoreHudTestMaxWidgets() -> Int32 { return 800; }
