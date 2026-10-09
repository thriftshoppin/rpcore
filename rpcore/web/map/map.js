(() => {
  'use strict';
  const list = document.getElementById('locations');
  const status = document.getElementById('status');
  const editor = document.getElementById('editor');
  const editToggle = document.getElementById('edit-toggle');
  const editorStatus = document.getElementById('editor-status');
  const labelInput = document.getElementById('pin-label');
  const idInput = document.getElementById('pin-id');
  let editorAllowed = false;
  let idManuallyEdited = false;

  function setEditorVisible(visible) {
    editor.hidden = !visible;
    if (visible) {
      let saved = null;
      try { saved = localStorage.getItem('rpcore-map-editor-position'); } catch (_) { /* session can still use the panel */ }
      if (saved) {
        try {
          const position = JSON.parse(saved);
          const x = Math.max(0, Math.min(innerWidth - editor.offsetWidth, Number(position.x) || 0));
          const y = Math.max(0, Math.min(innerHeight - editor.offsetHeight, Number(position.y) || 0));
          editor.style.left = `${x}px`; editor.style.top = `${y}px`; editor.style.right = 'auto';
        }
        catch (_) { /* keep default position */ }
      }
    }
  }

  function makeDraggable() {
    const handle = document.getElementById('editor-drag');
    let drag = null;
    handle.addEventListener('pointerdown', event => {
      if (event.target.closest('button')) return;
      const rect = editor.getBoundingClientRect();
      drag = { x: event.clientX - rect.left, y: event.clientY - rect.top };
      handle.setPointerCapture(event.pointerId);
    });
    handle.addEventListener('pointermove', event => {
      if (!drag) return;
      const x = Math.max(0, Math.min(innerWidth - editor.offsetWidth, event.clientX - drag.x));
      const y = Math.max(0, Math.min(innerHeight - editor.offsetHeight, event.clientY - drag.y));
      editor.style.left = `${x}px`; editor.style.top = `${y}px`; editor.style.right = 'auto';
    });
    const end = () => {
      if (!drag) return;
      drag = null;
      const rect = editor.getBoundingClientRect();
      try { localStorage.setItem('rpcore-map-editor-position', JSON.stringify({ x: rect.left, y: rect.top })); }
      catch (_) { /* panel remains movable for this session */ }
    };
    handle.addEventListener('pointerup', end); handle.addEventListener('pointercancel', end);
  }

  function setAdminEditor(allowed) {
    editorAllowed = allowed === true;
    editToggle.hidden = !editorAllowed;
    if (!editorAllowed) setEditorVisible(false);
  }
  function render(locations, error) {
    list.textContent = '';
    if (error) {
      const unavailable = document.createElement('li'); unavailable.className = 'empty';
      unavailable.textContent = `Saved locations are unavailable: ${error}. Check EventCore persistence and the server database setting.`;
      list.appendChild(unavailable); status.textContent = 'Storage unavailable'; return;
    }
    if (!Array.isArray(locations) || locations.length === 0) {
      const empty = document.createElement('li'); empty.className = 'empty'; empty.textContent = 'No saved locations yet.'; list.appendChild(empty);
      status.textContent = '0 locations'; return;
    }
    status.textContent = `${locations.length} saved location${locations.length === 1 ? '' : 's'}`;
    locations.forEach(location => {
      if (!location || typeof location.id !== 'string' || typeof location.label !== 'string' || !location.position) return;
      const row = document.createElement('li'); const details = document.createElement('div'); details.className = 'place';
      const title = document.createElement('div'); title.className = 'name'; title.textContent = location.label;
      const coords = document.createElement('div'); coords.className = 'coords';
      coords.textContent = `${Number(location.position.x).toFixed(1)}, ${Number(location.position.y).toFixed(1)}, ${Number(location.position.z).toFixed(1)}`;
      details.append(title, coords); const route = document.createElement('button'); route.className = 'route'; route.type = 'button'; route.textContent = 'Route';
      route.addEventListener('click', () => window.Open77 && Open77.emit('rpcore:map:track', { id: location.id }));
      row.append(details, route); list.appendChild(row);
    });
  }
  document.getElementById('refresh').addEventListener('click', () => window.Open77 && Open77.emit('rpcore:map:refresh', {}));
  editToggle.addEventListener('click', () => setEditorVisible(editor.hidden));
  document.getElementById('editor-close').addEventListener('click', () => setEditorVisible(false));
  labelInput.addEventListener('input', () => {
    if (!idManuallyEdited) idInput.value = labelInput.value.toLowerCase().trim().replace(/[^a-z0-9_-]+/g, '-').replace(/^[^a-z0-9]+/, '').slice(0, 48);
  });
  idInput.addEventListener('input', () => { idManuallyEdited = true; });
  document.getElementById('pin-form').addEventListener('submit', event => {
    event.preventDefault();
    if (!editorAllowed || !window.Open77) return;
    editorStatus.textContent = 'Saving…';
    Open77.emit('rpcore:map:create', { id: idInput.value.trim(), label: labelInput.value.trim(), sprite: document.getElementById('pin-sprite').value });
  });
  makeDraggable();
  if (window.Open77 && typeof Open77.on === 'function') {
    Open77.on('rpcore:map:locations', data => {
      setAdminEditor(data && data.editorAllowed);
      render(data && data.locations, data && data.error);
    });
    Open77.on('rpcore:map:create:result', result => {
      if (result && result.ok) {
        editorStatus.textContent = `Saved ${result.id} (${result.outcome}).`;
        document.getElementById('pin-form').reset();
        idManuallyEdited = false;
        Open77.emit('rpcore:map:refresh', {});
      } else editorStatus.textContent = `Could not save pin: ${result && result.error || 'unknown error'}`;
    });
    Open77.on('open77:map:tabState', state => { if (state && state.active) Open77.emit('rpcore:map:refresh', {}); });
    Open77.emit('rpcore:map:refresh', {});
  } else status.textContent = 'Open77 map bridge unavailable.';
})();
