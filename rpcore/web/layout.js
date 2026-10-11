// Shared mouse-driven layout editor for RPCore's independent WebUI panels.
(() => {
  const styles = `
    .rpcore-layout-tools{position:fixed;z-index:2147483647;left:50%;top:12px;transform:translateX(-50%);display:none;align-items:center;gap:5px;padding:6px 8px;color:#eaf7ff;background:rgba(3,12,21,.96);border:1px solid rgba(25,217,245,.55);box-shadow:0 5px 22px #0009;font:700 11px Rajdhani,Bahnschrift,sans-serif;letter-spacing:.06em;pointer-events:auto;white-space:nowrap}
    body.rpcore-layout-active .rpcore-layout-tools{display:flex}
    .rpcore-layout-tools button{border:1px solid #19d9f566;background:#09202b;color:#c9f8ff;padding:5px 7px;font:inherit;cursor:pointer}
    .rpcore-layout-tools button:hover,.rpcore-layout-tools button[aria-current=true]{background:#19d9f533;color:white}
    .rpcore-layout-scale{min-width:38px;text-align:center;color:#19d9f5;font:700 10px 'IBM Plex Mono',monospace}
    body.rpcore-layout-active [data-layout-id]{outline:1px dashed #19d9f5aa!important;outline-offset:2px;cursor:grab;pointer-events:auto!important;touch-action:none}
    body.rpcore-layout-active [data-layout-id]:active{cursor:grabbing}
    .rpcore-layout-placeholder{position:absolute!important;inset:0!important;z-index:2147483000;display:none!important;min-width:0!important;min-height:0!important;align-items:center;justify-content:center;padding:8px!important;color:#a9eefa!important;background:rgba(4,18,28,.88)!important;border:1px dashed #19d9f5aa!important;font:700 11px Rajdhani,Bahnschrift,sans-serif!important;letter-spacing:.12em;text-transform:uppercase;pointer-events:none}
    body.rpcore-layout-active [data-layout-id]>.rpcore-layout-placeholder{display:flex!important}
    body.rpcore-layout-active [data-layout-id]>*:not(.rpcore-layout-placeholder){visibility:hidden!important}
    body.rpcore-layout-active #rpcore-hud,body.rpcore-layout-active .occupation-panel,body.rpcore-layout-active #stack,body.rpcore-layout-active #journal,body.rpcore-layout-active #controls,body.rpcore-layout-active .weapon-hud{visibility:visible!important}
    body.rpcore-layout-active .occupation-panel{display:flex!important;width:200px;height:54px;min-width:0}
    body.rpcore-layout-active #stack{display:flex!important;width:210px;height:70px;min-height:0}
    body.rpcore-layout-active #journal,body.rpcore-layout-active #controls{display:block!important;width:240px;height:82px;max-height:none;min-height:0;overflow:hidden;padding:0!important}
    body.rpcore-layout-active .weapon-hud{display:block!important;width:220px;height:72px;min-height:0}
    .rp-ctl-hidden{display:none!important}
    #stack{transform:scale(calc(var(--scale) * var(--layout-scale,.85)))}
    #journal{transform:translateY(-50%) scale(calc(var(--scale) * var(--layout-scale,.85)))}
    #controls{transform:translate(-50%,-50%) scale(var(--layout-scale,.85))}
    .weapon-hud{--layout-scale:.78;transform:rotateY(-7deg) scale(var(--layout-scale))}
    #occupation-panel{--layout-scale:.78}
    body.rpcore-layout-active #rpcore-hud{width:min(280px,30vw);grid-template-columns:50px minmax(0,1fr);gap:7px}
    body.rpcore-layout-active #rpcore-hud .rail{grid-template-rows:52px 76px;gap:5px}
    body.rpcore-layout-active #rpcore-hud .body-card svg{width:36px;height:60px}
    body.rpcore-layout-active #rpcore-hud .vital{min-height:27px;grid-template-columns:24px minmax(0,1fr) 60px;gap:4px;padding:2px 4px 2px 3px}
    body.rpcore-layout-active #rpcore-hud .icon-cell{width:25px;height:25px}
    body.rpcore-layout-active #rpcore-hud .icon-cell svg{width:18px;height:18px}
    body.rpcore-layout-active #rpcore-hud .label{font-size:10px}
    body.rpcore-layout-active #rpcore-hud .meter{height:9px}
    body.rpcore-layout-active #rpcore-hud .value{font-size:9px}
  `;

  function install(surface, ids) {
    const css = document.createElement('style'); css.textContent = styles; document.head.appendChild(css);
    const tools = document.createElement('nav'); tools.className = 'rpcore-layout-tools';
    tools.setAttribute('aria-label', 'RPCore HUD layout editor');
    tools.innerHTML = '<span>DRAG</span><button type="button" data-action="surface" data-value="vitals">Vitals</button><button type="button" data-action="surface" data-value="activities">Activities</button><button type="button" data-action="surface" data-value="weapon">Weapon</button><button type="button" data-action="size" data-delta="-0.05" aria-label="Smaller panel">−</button><output class="rpcore-layout-scale">45%</output><button type="button" data-action="size" data-delta="0.05" aria-label="Larger panel">+</button><button type="button" data-action="reset">Reset</button><button type="button" data-action="close">Done</button>';
    document.body.appendChild(tools);

    for (const id of ids) {
      const element = document.querySelector(`[data-layout-id="${id}"]`);
      if (!element) continue;
      if (getComputedStyle(element).position === 'static') element.style.position = 'relative';
      const placeholder = document.createElement('div');
      placeholder.className = 'rpcore-layout-placeholder';
      placeholder.textContent = id.replace(/[-_]/g, ' ');
      element.appendChild(placeholder);
    }

    function defaultScale(element) { return element?.dataset.layoutId === 'vitals' ? .45 : .78; }
    function panelScale(element) {
      const scale = Number(getComputedStyle(element).getPropertyValue('--layout-scale'));
      return Number.isFinite(scale) && scale > 0 ? scale : defaultScale(element);
    }
    function place(element, point) {
      if (!point || !Number.isFinite(point.x) || !Number.isFinite(point.y)) return;
      element.style.position = 'fixed';
      element.style.left = `${point.x * 100}vw`;
      element.style.top = `${point.y * 100}vh`;
      element.style.right = 'auto'; element.style.bottom = 'auto';
      element.style.transformOrigin = 'top left';
      const scale = Number.isFinite(Number(point.scale)) ? Math.max(.35, Math.min(1, Number(point.scale))) : defaultScale(element);
      element.style.setProperty('--layout-scale', String(scale));
    }
    // ── server-driven element control (EventCore -> RPCore -> here) ──────────
    // Each page applies only the elements it contains. An override placement wins
    // over the player's saved F9 position while it is set; clearing it hands the
    // element back. Overridden elements are locked against dragging.
    const SELECTORS = {
      vitals: '[data-layout-id="vitals"]', occupation: '[data-layout-id="occupation"]',
      weapon: '[data-layout-id="weapon"]', stack: '[data-layout-id="stack"]',
      journal: '[data-layout-id="journal"]', controls: '[data-layout-id="controls"]',
      level: '#level-card',
    };
    for (const vital of ['health', 'stamina', 'armor', 'breath', 'food', 'water', 'sanity']) {
      SELECTORS['vital.' + vital] = `[data-vital="${vital}"]`;
    }
    let controlState = {};
    function controlPlacement(id) {
      const entry = controlState[id];
      return entry && entry.placement && Number.isFinite(Number(entry.placement.x)) && Number.isFinite(Number(entry.placement.y))
        ? entry.placement : null;
    }
    function effectivePoint(id, saved) {
      const forced = controlPlacement(id);
      if (!forced) return saved || null;
      const scale = forced.scale !== undefined && forced.scale !== null ? forced.scale : (saved ? saved.scale : undefined);
      return { x: Number(forced.x), y: Number(forced.y), scale };
    }
    function applyControl(payload) {
      const elements = payload && typeof payload.elements === 'object' && payload.elements ? payload.elements : {};
      controlState = elements;
      for (const [id, selector] of Object.entries(SELECTORS)) {
        const element = document.querySelector(selector);
        if (!element) continue;
        const entry = controlState[id];
        element.classList.toggle('rp-ctl-hidden', !!entry && entry.visible === false);
        if (entry && typeof entry.opacity === 'number' && Number.isFinite(entry.opacity)) {
          element.style.opacity = String(Math.max(0, Math.min(1, entry.opacity)));
        } else element.style.removeProperty('opacity');
      }
      if (currentState) apply(currentState); // re-resolve placement: override > saved > default
    }

    let currentState = null;
    let lastMoved = null;
    function activeElement() { return document.querySelector(`[data-layout-id="${lastMoved || ids[0]}"]`); }
    function updateScaleReadout() {
      const element = activeElement();
      const scale = element ? panelScale(element) : .45;
      const output = tools.querySelector('.rpcore-layout-scale');
      if (output) output.value = `${Math.round(scale * 100)}%`;
    }
    function apply(state) {
      currentState = state || {};
      document.body.classList.toggle('rpcore-layout-active', !!currentState.enabled);
      tools.querySelectorAll('[data-action="surface"]').forEach(button => button.setAttribute('aria-current', String(button.dataset.value === currentState.focused)));
      const saved = currentState.positions || {};
      for (const id of ids) {
        const element = document.querySelector(`[data-layout-id="${id}"]`);
        if (!element) continue;
        const point = effectivePoint(id, saved[id]);
        if (point) place(element, point);
        else {
          for (const property of ['position','left','top','right','bottom','transform-origin','--layout-scale']) element.style.removeProperty(property);
        }
      }
      updateScaleReadout();
    }
    tools.addEventListener('click', event => {
      const button = event.target.closest('button'); if (!button || !window.Open77) return;
      if (button.dataset.action === 'close') Open77.emit('rpcore:layout:close', {});
      else if (button.dataset.action === 'reset') Open77.emit('rpcore:layout:reset', { element: lastMoved || ids[0] });
      else if (button.dataset.action === 'size') {
        const element = activeElement(); if (!element) return;
        if (controlPlacement(element.dataset.layoutId)) return; // placed by the server
        const scale = Math.max(.35, Math.min(1, panelScale(element) + Number(button.dataset.delta)));
        element.style.setProperty('--layout-scale', String(scale));
        updateScaleReadout();
        const rect = element.getBoundingClientRect();
        Open77.emit('rpcore:layout:save', { element: element.dataset.layoutId, x: rect.left / innerWidth, y: rect.top / innerHeight, scale });
      } else Open77.emit('rpcore:layout:select', { surface: button.dataset.value });
    });

    let dragging = null;
    document.addEventListener('pointerdown', event => {
      if (!document.body.classList.contains('rpcore-layout-active') || event.button !== 0) return;
      const element = event.target.closest('[data-layout-id]');
      if (!element || event.target.closest('.rpcore-layout-tools')) return;
      if (controlPlacement(element.dataset.layoutId)) return; // placed by the server
      const rect = element.getBoundingClientRect();
      lastMoved = element.dataset.layoutId;
      dragging = { element, dx: event.clientX - rect.left, dy: event.clientY - rect.top };
      updateScaleReadout(); event.preventDefault();
    }, true);
    document.addEventListener('pointermove', event => {
      if (!dragging) return;
      const { element } = dragging;
      const rect = element.getBoundingClientRect();
      const x = Math.max(0, Math.min(innerWidth - rect.width, event.clientX - dragging.dx));
      const y = Math.max(0, Math.min(innerHeight - rect.height, event.clientY - dragging.dy));
      place(element, { x: x / innerWidth, y: y / innerHeight, scale: panelScale(element) });
    });
    document.addEventListener('pointerup', () => {
      if (!dragging) return;
      const element = dragging.element; dragging = null;
      const rect = element.getBoundingClientRect();
      if (window.Open77) Open77.emit('rpcore:layout:save', { element: element.dataset.layoutId, x: rect.left / innerWidth, y: rect.top / innerHeight, scale: panelScale(element) });
    });
    if (window.Open77 && typeof Open77.on === 'function') {
      Open77.on('rpcore:layout:state', apply);
      Open77.on('rpcore:element:control', applyControl);
      Open77.emit('rpcore:layout:ready', { surface });
    }
    window.RPCoreLayout = { apply };
  }
  window.RPCoreLayoutInstall = install;
})();
