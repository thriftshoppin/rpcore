(() => {
  "use strict";
  // RPCore weapon readout, text only: name, class, drawn/holstered, rounds.
  const body = document.body;
  const $ = id => document.getElementById(id);
  const card = $("weapon-hud");
  const whole = v => Math.max(0, Math.round(Number(v) || 0));

  function render(p) {
    if (!p || typeof p !== "object") return;
    const w = p.weapon && typeof p.weapon === "object" ? p.weapon : {};
    const equipped = w.equipped === true;
    body.dataset.visible = String(p.visible === true);
    body.dataset.weapon = String(equipped);
    if (!equipped) return;

    const W = window.RPCoreWeapons;
    const cls = W ? W.classify(w) : "pistol";
    const melee = W ? W.isMelee(cls) : false;
    const drawn = w.drawn === true;
    const known = w.ammoKnown === true;
    const mag = whole(w.magazine), cap = whole(w.capacity), res = whole(w.reserve);
    const low = known && cap > 0 && mag <= Math.ceil(cap * 0.25);

    card.classList.toggle("melee", melee);
    card.classList.toggle("drawn", drawn);
    card.classList.toggle("holstered", !drawn);
    card.classList.toggle("low-ammo", low && !melee);
    $("weapon-name").textContent = W ? W.displayName(w) : String(w.record || "Weapon");
    $("weapon-type").textContent = W ? W.CLASS_LABEL[cls] : "WEAPON";
    $("weapon-state").textContent = drawn ? (low && !melee ? "RELOAD" : "DRAWN") : "HOLSTERED";
    $("ammo-magazine").textContent = known ? String(mag) : "--";
    $("ammo-reserve").textContent = known ? String(res) : "--";
  }

  if (window.Open77 && typeof Open77.on === "function") {
    Open77.on("rpcore:weapon", render);
    if (typeof Open77.ready === "function") Open77.ready();
    Open77.emit("rpcore:weapon:ready", {});
  } else {
    // Browser preview: weapon.html?preview=Items.Base_Ajax&mag=6&cap=30&res=240[&holstered]
    const q = new URLSearchParams(location.search);
    if (q.has("preview")) render({ visible: true, weapon: { equipped: true, drawn: !q.has("holstered"), slot: 1,
      record: q.get("preview") || "Items.Base_Ajax", ammoKnown: true,
      magazine: Number(q.get("mag") || 24), capacity: Number(q.get("cap") || 30), reserve: Number(q.get("res") || 240) } });
  }
})();
