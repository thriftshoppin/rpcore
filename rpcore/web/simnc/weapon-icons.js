// SIMNC weapon helpers (names, classes). Formerly also photoreal 3D renders (original SIMNC models, rendered in Blender),
// one per weapon class, shipped as web/weapons/<class>.webp (transparent, 3/4 tilt).
// Exposes window.SimncWeapons = { icon(cls), classify(weapon), displayName(weapon), CLASS_LABEL, isMelee }.
(() => {
  "use strict";

  const CLASSES = ["pistol", "techpistol", "revolver", "smg", "rifle", "precision", "sniper", "shotgun",
    "doublebarrel", "lmg", "launcher", "katana", "knife", "machete", "axe", "chainsword", "blunt", "hammer"];

  // No renders are drawn any more (the card is text only); `icon()` is kept for
  // anything that still asks, and nothing is preloaded.

  const CLASS_LABEL = {
    pistol: "PISTOL", techpistol: "TECH PISTOL", revolver: "REVOLVER",
    smg: "SMG", rifle: "ASSAULT RIFLE", precision: "PRECISION RIFLE", sniper: "SNIPER RIFLE",
    shotgun: "SHOTGUN", doublebarrel: "DOUBLE-BARREL", lmg: "LMG", launcher: "LAUNCHER",
    katana: "KATANA", knife: "KNIFE", machete: "MACHETE", axe: "AXE", chainsword: "CHAINSWORD",
    blunt: "BLUNT", hammer: "HAMMER",
  };
  const MELEE = new Set(["katana", "knife", "machete", "axe", "chainsword", "blunt", "hammer"]);

  // Record keyword -> class. Order matters: first match wins.
  const RULES = [
    ["chainsword", /chainsword/],
    ["hammer", /hammer|sledge|mallet/],
    ["axe", /\baxe|_axe|hatchet/],
    ["machete", /machete|kukri|cleaver/],
    ["katana", /katana|sword|tojinbo|satori|jinchu|nehan|scalpel|kanabo/],
    ["knife", /knife|tanto|stiletto|dagger|butterfly|mantis/],
    ["blunt", /bat\b|_bat|blunt|club|crowbar|pipe|tire|baton|wrench|mace|dildo|golf|shovel/],
    ["launcher", /authority|launcher|grenade_?launcher|rpg/],
    ["lmg", /defender|ma70|hmg|lmg|mg_?|minigun/],
    ["doublebarrel", /igla|palica|satara|testera|double/],
    ["shotgun", /carnage|crusher|pozhar|tactician|zhuo|shotgun|sovereign|guts/],
    ["sniper", /ashura|grad|nekomata|osprey|rasetsu|sniper|breakthrough|overwatch/],
    ["precision", /achilles|kolac|sor22|sor-22|precision|widow|o'?five/],
    ["rifle", /ajax|copperhead|hercules|kyubi|masamune|sidewinder|umbra|rifle|ar_|genjiroh|moron|psalm|prejudice|divided/],
    ["smg", /dian|borg|guillotine|pulsar|saratoga|senkoh|shingen|warden|smg|buzzsaw|fenrir|yinglong|problem/],
    ["revolver", /burya|metel|nova|overture|quasar|revolver|malorian|crash|amnesty|archangel|comrade/],
    ["techpistol", /kenshin|yukimura|kappa|omaha|smart|apparition|skippy|chaos/],
    ["pistol", /lexington|chao|grit|liberty|nue|slaughtomatic|ticon|unity|pistol|handgun|dying|plan_b|kongou|lizzie/],
  ];

  // Friendly names for the stock records (what the card title shows).
  const NAMES = {
    lexington: "M-10AF Lexington", chao: "A-22B Chao", grit: "HA-4 Grit", kappa: "Kappa", kenshin: "JKE-X2 Kenshin",
    liberty: "Liberty", nue: "Nue", omaha: "M-76e Omaha", slaughtomatic: "Slaught-O-Matic", ticon: "Ticon",
    unity: "Unity", yukimura: "HJKE-11 Yukimura", burya: "RT-46 Burya", metel: "Metel", nova: "DR5 Nova",
    overture: "Overture", quasar: "DR-12 Quasar", dian: "G-58 Dian", borg4a: "Borg4a", guillotine: "Guillotine",
    pulsar: "DS1 Pulsar", saratoga: "M221 Saratoga", senkoh: "Senkoh LX", shingen: "TKI-20 Shingen", warden: "Warden",
    ajax: "M251s Ajax", copperhead: "D5 Copperhead", hercules: "Hercules 3AX", kyubi: "Kyubi", masamune: "HJSH-18 Masamune",
    sidewinder: "D5 Sidewinder", umbra: "DA8 Umbra", achilles: "M-179e Achilles", kolac: "Kolac", sor22: "SOR-22",
    ashura: "Ashura", grad: "SPT32 Grad", nekomata: "Nekomata", osprey: "NDI Osprey", rasetsu: "Rasetsu",
    carnage: "Carnage", crusher: "Crusher", pozhar: "VST-37 Pozhar", tactician: "M2038 Tactician", zhuo: "L-69 Zhuo",
    igla: "DB-4 Igla", palica: "DB-4 Palica", satara: "DB-2 Satara", testera: "DB-2 Testera", defender: "M2067 Defender",
    ma70: "MA70 HB", hmg: "Mk.31 HMG", authority: "Authority", katana: "Katana", crowbar: "Crowbar", bat: "Baseball Bat",
    axe: "Axe", knife: "Knife", machete: "Machete", machete_kukri: "Kukri", two_hand_hammer: "Sledgehammer",
    two_hand_blunt: "Club", chainsword: "Chainsword",
  };

  const key = w => String(w.record || "").toLowerCase()
    .replace(/^items\./, "").replace(/^(preset|base|craftable_(common|uncommon|rare|epic|legendary)|w_\w+?)_/, "")
    .replace(/_(default|player|pimp\w*|nomad\w*|\d+)$/g, "");

  function classify(w) {
    const hay = `${String(w.record || "")} ${String(w.label || "")} ${String(w.category || "")}`.toLowerCase();
    for (const [cls, re] of RULES) if (re.test(hay)) return cls;
    return /melee|blade|blunt/.test(hay) ? "knife" : "pistol";
  }

  function displayName(w) {
    const k = key(w);
    if (NAMES[k]) return NAMES[k];
    const first = k.split("_")[0];
    if (NAMES[first]) return NAMES[first];
    const label = String(w.label || "").replace(/^(base|preset|craftable common)\s+/i, "").trim();
    const src = label || k.replace(/_/g, " ");
    return src ? src.replace(/\b\w/g, c => c.toUpperCase()) : "Weapon";
  }

  window.SimncWeapons = {
    icon: cls => `<img src="weapons/${CLASSES.includes(cls) ? cls : "pistol"}.webp" alt="" draggable="false">`,
    classify, displayName, CLASS_LABEL, isMelee: cls => MELEE.has(cls), classes: CLASSES.slice(),
  };
})();
