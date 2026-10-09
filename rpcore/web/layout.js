// Shared mouse-driven layout editor for RPCore's WebUI panels.
(() => {
  const styles = `
    .rpcore-layout-tools{position:fixed;z-index:2147483647;left:50%;top:16px;transform:translateX(-50%);display:none;align-items:center;gap:6px;padding:7px 9px;color:#eaf7ff;background:rgba(3,12,21,.94);border:1px solid rgba(25,217,245,.55);box-shadow:0 5px 22px #0009;font:700 12px Rajdhani,Bahnschrift,sans-serif;letter-spacing:.08em;pointer-events:auto}
    body.rpcore-layout-active .rpcore-layout-tools{display:flex}
    .rpcore-layout-tools button{border:1px solid #19d9f566;background:#09202b;color:#c9f8ff;padding:6px 9px;font:inherit;cursor:pointer}
    .rpcore-layout-tools button:hover,.rpcore-layout-tools button[aria-current=true]{background:#19d9f533;color:white}
    body.rpcore-layout-active [data-layout-id]{outline:1px dashed #19d9f5aa;outline-offset:3px;cursor:grab;pointer-events:auto!important;touch-action:none}
    body.rpcore-layout-active [data-layout-id]:active{cursor:grabbing}
    .rpcore-layout-placeholder{display:none;min-width:220px;min-height:62px;align-items:center;justify-content:center;padding:16px;color:#a9eefa;background:rgba(4,18,28,.86);border:1px dashed #19d9f5aa;font:700 12px Rajdhani,Bahnschrift,sans-serif;letter-spacing:.12em;text-transform:uppercase}
    body.rpcore-layout-active .rpcore-layout-placeholder{display:none}
    body.rpcore-layout-active #stack,body.rpcore-layout-active #journal,body.rpcore-layout-active #controls{visibility:visible!important}
    body.rpcore-layout-active [data-layout-empty=true] .rpcore-layout-placeholder{display:flex}
    body.rpcore-layout-active #rpcore-hud{visibility:visible!important}
    body.rpcore-layout-active .occupation-panel{display:flex!important;visibility:visible!important}
    body.rpcore-layout-active .weapon-hud{display:block!important;visibility:visible!important}
    body.rpcore-layout-active #journal,body.rpcore-layout-active #controls{display:flex!important;visibility:visible!important}
    body.rpcore-layout-active #journal{max-height:none}
  `;

  function install(surface, ids) {
    const css = document.createElement('style'); css.textContent = styles; document.head.appendChild(css);
    const tools = document.createElement('nav'); tools.className = 'rpcore-layout-tools';
    tools.setAttribute('aria-label', 'RPCore HUD layout editor');
    tools.innerHTML = '<span>DRAG PANELS</span><button type="button" data-action="surface" data-value="vitals">Vitals</button><button type="button" data-action="surface" data-value="activities">Activities</button><button type="button" data-action="surface" data-value="weapon">Weapon</button><button type="button" data-action="reset">Reset panel</button><button type="button" data-action="close">Done</button>';
    document.body.appendChild(tools);

    for (const id of ids) {
      const element = document.querySelector(`[data-layout-id="${id}"]`);
      if (!element) continue;
      const placeholder = document.createElement('div');
      placeholder.className = 'rpcore-layout-placeholder';
      placeholder.textContent = id.replace(/[-_]/g, ' ');
      placeholder.dataset.layoutPlaceholder = 'true';
      element.appendChild(placeholder);
    }

    function place(element, point) {
      if (!point || !Number.isFinite(point.x) || !Number.isFinite(point.y)) return;
      element.style.position = 'fixed';
      element.style.left = `${point.x * 100}vw`;
      element.style.top = `${point.y * 100}vh`;
      element.style.right = 'auto'; element.style.bottom = 'auto'; element.style.transform = 'none';
      element.style.transformOrigin = 'top left';
    }
    function apply(state) {
      document.body.classList.toggle('rpcore-layout-active', !!(state && state.enabled));
      tools.querySelectorAll('[data-action="surface"]').forEach(button => {
        button.setAttribute('aria-current', String(button.dataset.value === state?.focused));
      });
      const saved = state && state.positions || {};
      for (const id of ids) {
        const element = document.querySelector(`[data-layout-id="${id}"]`);
        if (!element) continue;
        const placeholder = element.querySelector('.rpcore-layout-placeholder');
        const visibleChild = Array.from(element.children).some(child => child !== placeholder
          && !child.hidden && getComputedStyle(child).display !== 'none');
        element.dataset.layoutEmpty = String(!visibleChild);
        if (saved[id]) place(element, saved[id]);
        else {
          for (const property of ['position','left','top','right','bottom','transform','transform-origin']) element.style.removeProperty(property);
        }
      }
    }
    let lastMoved = null;
    tools.addEventListener('click', event => {
      const button = event.target.closest('button'); if (!button || !window.Open77) return;
      if (button.dataset.action === 'close') Open77.emit('rpcore:layout:close', {});
      else if (button.dataset.action === 'reset') Open77.emit('rpcore:layout:reset', { element: lastMoved || ids[0] });
      else Open77.emit('rpcore:layout:select', { surface: button.dataset.value });
    });

    let dragging = null;
    document.addEventListener('pointerdown', event => {
      if (!document.body.classList.contains('rpcore-layout-active') || event.button !== 0) return;
      const element = event.target.closest('[data-layout-id]');
      if (!element || event.target.closest('.rpcore-layout-tools')) return;
      const rect = element.getBoundingClientRect();
      lastMoved = element.dataset.layoutId;
      dragging = { element, dx: event.clientX - rect.left, dy: event.clientY - rect.top };
      event.preventDefault();
    }, true);
    document.addEventListener('pointermove', event => {
      if (!dragging) return;
      const element = dragging.element;
      const x = Math.max(0, Math.min(innerWidth - element.offsetWidth, event.clientX - dragging.dx));
      const y = Math.max(0, Math.min(innerHeight - element.offsetHeight, event.clientY - dragging.dy));
      place(element, { x: x / innerWidth, y: y / innerHeight });
    });
    document.addEventListener('pointerup', () => {
      if (!dragging) return;
      const element = dragging.element; dragging = null;
      const rect = element.getBoundingClientRect();
      if (window.Open77) Open77.emit('rpcore:layout:save', { element: element.dataset.layoutId,
        x: rect.left / innerWidth, y: rect.top / innerHeight });
    });
    if (window.Open77 && typeof Open77.on === 'function') {
      Open77.on('rpcore:layout:state', apply);
      Open77.emit('rpcore:layout:ready', { surface });
    }
    new MutationObserver(() => {
      for (const id of ids) {
        const element = document.querySelector(`[data-layout-id="${id}"]`);
        const placeholder = element && element.querySelector('.rpcore-layout-placeholder');
        if (!element || !placeholder) continue;
        const visibleChild = Array.from(element.children).some(child => child !== placeholder
          && !child.hidden && getComputedStyle(child).display !== 'none');
        element.dataset.layoutEmpty = String(!visibleChild);
      }
    }).observe(document.body, { attributes: true, subtree: true, attributeFilter: ['hidden'] });
    window.RPCoreLayout = { apply };
  }
  window.RPCoreLayoutInstall = install;
})();
