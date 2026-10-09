/* RPCore HUD renderer. Pure view: it draws what the server sends and holds no
   activity logic. Messages arrive on 'rpcore:ui' as { type, ... } (see
   server/presentation.lua). A developer preview works in a normal browser:
   open index.html?preview and use RPCorePreview.run(). */
(function () {
  'use strict';
  var $ = function (id) { return document.getElementById(id); };
  var cfg = { ui: {}, keys: {} };
  var cards = { offer: $('offer'), tracker: $('tracker'), result: $('result'), toast: $('toast') };
  var timers = {};
  var chain = Promise.resolve();        // serialises messages that must not overlap
  var current = null;                   // activity currently in the tracker
  var journalOpen = false, journalData = { active: null, history: [] }, tab = 'active';
  var controlsOpen = false, bindings = [], capturing = null;

  var sleep = function (ms) { return new Promise(function (r) { setTimeout(r, ms); }); };
  var pad = function (n) { return (n < 10 ? '0' : '') + n; };
  var text = function (el, v) { el.textContent = v == null ? '' : String(v); };
  var q = function (card, sel) { return card.querySelector(sel); };

  function show(card) { card.classList.remove('leaving'); card.hidden = false; card.style.animation = 'none'; void card.offsetWidth; card.style.animation = ''; }
  function hide(name, fast) {
    var card = cards[name]; if (!card || card.hidden) return;
    clearTimeout(timers[name]);
    if (fast) { card.hidden = true; return; }
    card.classList.add('leaving');
    setTimeout(function () { if (card.classList.contains('leaving')) { card.hidden = true; card.classList.remove('leaving'); } }, 180);
  }
  function autoHide(name, ms) { clearTimeout(timers[name]); timers[name] = setTimeout(function () { hide(name); }, ms); }

  function applyConfig(c) {
    cfg = c || cfg; var ui = cfg.ui || {}, root = document.documentElement.style;
    document.body.dataset.anchor = ui.anchor || 'top-right';
    root.setProperty('--ox', (ui.offsetX || 24) + 'px'); root.setProperty('--oy', (ui.offsetY || 168) + 'px');
    root.setProperty('--scale', Math.min(1.5, Math.max(0.75, ui.scale || 1)));
    root.setProperty('--w-offer', (ui.offerWidth || 330) + 'px'); root.setProperty('--w-tracker', (ui.trackerWidth || 290) + 'px');
    var m = /^#?([0-9a-f]{6})$/i.exec(ui.accent || '');
    if (m) { var n = parseInt(m[1], 16); root.setProperty('--accent-rgb', (n >> 16) + ',' + ((n >> 8) & 255) + ',' + (n & 255)); }
    var brand = ui.brand || 'RPCORE';
    document.querySelectorAll('.brand').forEach(function (b) { b.textContent = brand; });
    var k = cfg.keys || {};
    text($('key-accept'), k.accept); text($('key-decline'), k.decline); text($('key-journal'), k.journal);
  }

  /* ── offer ── */
  function showOffer(msg) {
    var a = msg.activity, c = cards.offer;
    text(q(c, '.title'), a.name); text(q(c, '.desc'), a.description);
    var bar = q(c, '.timer'), fill = q(c, '.timer i');
    bar.hidden = !(msg.timeoutMs > 0);
    fill.style.transition = 'none'; fill.style.transform = 'scaleX(1)'; void fill.offsetWidth;
    if (msg.timeoutMs > 0) { fill.style.transition = 'transform ' + msg.timeoutMs + 'ms linear'; fill.style.transform = 'scaleX(0)'; }
    show(c);
  }

  /* ── tracker ── */
  function renderTracker(a) {
    current = a; var c = cards.tracker;
    text(q(c, '.title'), a.name);
    var o = q(c, '.objective'); o.classList.remove('done');
    text(q(c, '.otext'), a.objective ? a.objective.title : '');
    var d = q(c, '.odesc'); text(d, a.objective ? a.objective.description : ''); d.hidden = !(a.objective && a.objective.description);
    text(q(c, '.count'), pad(a.index) + ' / ' + pad(a.count));
    var segs = q(c, '.segs'); segs.textContent = '';
    for (var i = 1; i <= a.count; i++) {
      var s = document.createElement('i');
      if (a.objectives && a.objectives[i - 1] && a.objectives[i - 1].status === 'completed') s.className = 'on';
      else if (i === a.index) s.className = 'cur';
      segs.appendChild(s);
    }
    show(c);
  }
  function markDone(index) {
    if (!current) return;
    var c = cards.tracker, o = q(c, '.objective');
    o.classList.add('done');
    var segs = q(c, '.segs').children; if (segs[index - 1]) segs[index - 1].className = 'on';
  }

  /* ── result / toast ── */
  function showResult(msg, bad) {
    var a = msg.activity, c = cards.result;
    c.classList.toggle('bad', !!bad);
    text(q(c, '.kicker'), bad ? 'Activity ended' : 'Activity complete');
    text(q(c, '.title'), a.name);
    text(q(c, '.desc'), bad ? (msg.outcome === 'cancelled' ? 'This activity was cancelled.' : 'This activity was not completed.') : 'All objectives completed.');
    var r = q(c, '.reward');
    r.hidden = bad || !a.reward;
    if (!r.hidden) { text(q(r, '.amount'), a.reward.replace(/^\+\s*/, '')); setReward(a.rewardStatus || 'pending'); }
    hide('tracker', true); hide('offer', true);
    show(c); autoHide('result', (cfg.ui && cfg.ui.resultMs) || 7000);
  }
  function setReward(status) {
    var el = q(cards.result, '.rstate'); el.classList.toggle('bad', status === 'failed');
    text(el, status === 'granted' ? 'Delivered' : status === 'failed' ? 'Delivery failed \u2014 contact staff' : 'Processing');
  }
  function toast(msg) {
    text(q(cards.toast, '.desc'), msg); show(cards.toast); autoHide('toast', (cfg.ui && cfg.ui.notificationMs) || 6000);
  }

  /* ── journal (foundation) ── */
  function renderJournal() {
    var body = $('journal-body'); body.textContent = '';
    document.querySelectorAll('#journal .tabs button').forEach(function (b) { b.classList.toggle('on', b.dataset.tab === tab); });
    var list = tab === 'active' ? (journalData.active ? [journalData.active] : []) : (journalData.history || []);
    if (!list.length) { var e = document.createElement('div'); e.className = 'empty'; e.textContent = tab === 'active' ? 'No active activity.' : 'Nothing in your history yet.'; body.appendChild(e); return; }
    list.forEach(function (a) {
      var row = document.createElement('div'); row.className = 'entry';
      var name = document.createElement('div'); name.className = 'name';
      var n = document.createElement('span'); n.textContent = a.name; name.appendChild(n);
      var chip = document.createElement('span'); chip.className = 'chip' + (a.status === 'completed' || a.status === 'active' ? '' : ' bad'); chip.textContent = a.status; name.appendChild(chip);
      row.appendChild(name);
      var d = document.createElement('div'); d.className = 'd'; d.textContent = a.description; row.appendChild(d);
      if (tab === 'active') {
        var ul = document.createElement('ul');
        (a.objectives || []).forEach(function (o) { var li = document.createElement('li'); li.className = o.status === 'completed' ? 'done' : o.status === 'active' ? 'active' : ''; li.textContent = o.title; ul.appendChild(li); });
        row.appendChild(ul);
      }
      body.appendChild(row);
    });
  }
  function setJournal(open) { journalOpen = open; $('journal').hidden = !open; if (open) { show($('journal')); renderJournal(); } }

  /* ── controls / keybinding cheatsheet ── */
  function renderBindings() {
    var list = $('binding-list'); list.textContent = '';
    bindings.forEach(function (binding) {
      var row = document.createElement('div'); row.className = 'binding-row';
      var label = document.createElement('span'); label.className = 'binding-label'; label.textContent = binding.label;
      var key = document.createElement('kbd'); key.textContent = binding.key || 'UNBOUND';
      var button = document.createElement('button'); button.type = 'button'; button.dataset.id = binding.id;
      button.textContent = capturing === binding.id ? 'Press key…' : 'Change';
      button.setAttribute('aria-pressed', capturing === binding.id ? 'true' : 'false');
      button.addEventListener('click', function () { capturing = binding.id; setCaptureStatus('Press a key for ' + binding.label + '. ESC cancels.'); renderBindings(); });
      var reset = document.createElement('button'); reset.type = 'button'; reset.textContent = 'Reset'; reset.title = 'Restore the RPCore test default';
      reset.addEventListener('click', function () { capturing = null; Open77.emit('rpcore:bind:change', { id: binding.id, reset: true }); setCaptureStatus('Restoring default…'); });
      row.appendChild(label); row.appendChild(key); row.appendChild(button); row.appendChild(reset); list.appendChild(row);
    });
  }
  function setCaptureStatus(value, error) {
    var el = $('capture-status'); text(el, value); el.classList.toggle('error', !!error);
  }
  function setControls(open) {
    controlsOpen = open === true; $('controls').hidden = !controlsOpen;
    document.body.classList.toggle('controls-open', controlsOpen);
    if (!controlsOpen) { capturing = null; setCaptureStatus('ESC closes controls'); }
    else renderBindings();
  }
  function keyName(e) {
    if (/^Key[A-Z]$/.test(e.code)) return e.code.slice(3);
    if (/^Digit[0-9]$/.test(e.code)) return e.code.slice(5);
    if (/^F([1-9]|1[0-2])$/.test(e.key.toUpperCase())) return e.key.toUpperCase();
    var names = { Space: 'SPACE', Tab: 'TAB', Backspace: 'BACKSPACE', Delete: 'DELETE', Insert: 'INSERT', Home: 'HOME', End: 'END', PageUp: 'PAGEUP', PageDown: 'PAGEDOWN', ArrowUp: 'ARROWUP', ArrowDown: 'ARROWDOWN', ArrowLeft: 'ARROWLEFT', ArrowRight: 'ARROWRIGHT' };
    return names[e.code] || null;
  }
  function closeControls() { capturing = null; setControls(false); if (window.Open77 && Open77.emit) Open77.emit('rpcore:settings:close', {}); }
  $('controls-close').addEventListener('click', closeControls);
  $('layout-open').addEventListener('click', function () {
    if (window.Open77) Open77.emit('rpcore:layout:open', {});
  });
  document.addEventListener('keydown', function (e) {
    if (!controlsOpen) return;
    if (e.key === 'Escape') {
      e.preventDefault(); e.stopPropagation();
      if (capturing) { capturing = null; setCaptureStatus('Key change cancelled. ESC closes controls.'); renderBindings(); }
      else closeControls();
      return;
    }
    if (!capturing) return;
    e.preventDefault(); e.stopPropagation();
    var key = keyName(e);
    if (!key) { setCaptureStatus('That key is not supported. Try a letter, number, F key, or navigation key.', true); return; }
    Open77.emit('rpcore:bind:change', { id: capturing, key: key });
    setCaptureStatus('Saving ' + key + '…');
  }, true);

  /* ── message dispatch ── */
  function handle(msg) {
    switch (msg.type) {
      case 'offer': return showOffer(msg);
      case 'offerClosed':
        hide('offer');
        if (msg.outcome === 'declined') toast('Activity declined.');
        else if (msg.outcome === 'lapsed') toast('The offer is no longer available.');
        return;
      case 'tracker': return renderTracker(msg.activity);
      case 'objectiveDone':
        markDone(msg.index);
        return sleep((cfg.ui && cfg.ui.objectiveCheckMs) || 1300);
      case 'complete': return showResult(msg, false);
      case 'failed': return showResult(msg, true);
      case 'reward': if (!cards.result.hidden) setReward(msg.status); return;
      case 'clear': hide('tracker'); hide('offer'); current = null; return;
      case 'journal': journalData = msg; if (journalOpen) renderJournal(); return;
    }
  }
  function enqueue(msg) {
    if (!msg || typeof msg.type !== 'string') return;
    chain = chain.then(function () { return handle(msg); }).catch(function (e) { console.warn('[rpcore] render failed', e); });
  }

  document.querySelectorAll('#journal .tabs button').forEach(function (b) {
    b.addEventListener('click', function () { tab = b.dataset.tab; renderJournal(); });
  });

  if (window.Open77 && typeof Open77.on === 'function') {
    Open77.on('rpcore:config', applyConfig);
    Open77.on('rpcore:ui', enqueue);
    Open77.on('rpcore:visible', function (d) { document.body.classList.toggle('off', !(d && d.shown)); });
    Open77.on('rpcore:journal', function (d) { setJournal(!!(d && d.open)); });
    Open77.on('rpcore:settings', function (d) { setControls(!!(d && d.open)); });
    Open77.on('rpcore:keybinds', function (d) { bindings = d && Array.isArray(d.bindings) ? d.bindings : []; renderBindings(); });
    Open77.on('rpcore:bind:result', function (d) {
      if (!d) return;
      capturing = null;
      setCaptureStatus(d.ok ? ('Saved ' + d.key + '.') : ('Could not change key: ' + (d.key || 'unsupported by Open77.')), !d.ok);
      renderBindings();
    });
    Open77.emit('rpcore:ready', {});
  } else {
    console.warn('[rpcore] Open77 bridge not found \u2014 preview mode only.');
    applyConfig({ ui: { anchor: 'top-right', offsetX: 24, offsetY: 24, brand: 'RPCORE' }, keys: { accept: 'Y', decline: 'N', journal: 'J' } });
    var demo = { id: 'p1', name: 'Field Test', description: 'A short sequence of objectives that demonstrates the RPCore activity engine.', status: 'active', index: 1, count: 3, reward: '$500', rewardStatus: 'pending',
      objectives: [{ title: 'Acknowledge the briefing', status: 'active' }, { title: 'Stand by for the signal', status: 'pending' }, { title: 'Confirm the result', status: 'pending' }],
      objective: { title: 'Acknowledge the briefing', description: 'Press your action key to confirm you are ready.' } };
    window.RPCorePreview = { enqueue: enqueue, run: function () {
      enqueue({ type: 'offer', activity: demo, timeoutMs: 15000 });
      setTimeout(function () { enqueue({ type: 'offerClosed', id: 'p1', outcome: 'accepted' }); enqueue({ type: 'tracker', activity: demo }); }, 3000);
      setTimeout(function () { enqueue({ type: 'objectiveDone', id: 'p1', index: 1 }); var n = JSON.parse(JSON.stringify(demo)); n.index = 2; n.objectives[0].status = 'completed'; n.objectives[1].status = 'active'; n.objective = { title: 'Stand by for the signal', description: 'Hold position while the test runs.' }; enqueue({ type: 'tracker', activity: n }); }, 6000);
      setTimeout(function () { enqueue({ type: 'objectiveDone', id: 'p1', index: 3 }); enqueue({ type: 'complete', activity: demo }); }, 10000);
      setTimeout(function () { enqueue({ type: 'reward', id: 'p1', status: 'granted' }); }, 11500);
    } };
  }
})();
