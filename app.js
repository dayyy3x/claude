/* Mobile remote-access launcher — native-feeling PWA, all local. */
(() => {
  'use strict';

  // ---------- Storage ----------
  const K = { devices: 'ra_devices', theme: 'ra_theme', lastDevice: 'ra_last' };
  const load = (k, fb) => {
    try { const v = localStorage.getItem(k); return v == null ? fb : JSON.parse(v); }
    catch { return fb; }
  };
  const save = (k, v) => { try { localStorage.setItem(k, JSON.stringify(v)); } catch {} };
  const uid = () => Math.random().toString(36).slice(2, 10);

  // ---------- Haptics ----------
  const haptic = (ms = 10) => { try { navigator.vibrate?.(ms); } catch {} };

  // ---------- Theme ----------
  const themeToggle = document.getElementById('themeToggle');
  const themeIconUse = document.getElementById('themeIconUse');
  const systemPrefersDark = () =>
    window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
  const applyTheme = (t) => {
    document.documentElement.setAttribute('data-theme', t);
    const meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute('content', t === 'light' ? '#f4f6fb' : '#0b1020');
    themeIconUse?.setAttribute('href', t === 'light' ? '#i-sun' : '#i-moon');
  };
  let storedTheme = load(K.theme, null);
  let theme = storedTheme || (systemPrefersDark() ? 'dark' : 'light');
  applyTheme(theme);
  if (!storedTheme && window.matchMedia) {
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener?.('change', (e) => {
      if (load(K.theme, null)) return;
      theme = e.matches ? 'dark' : 'light';
      applyTheme(theme);
    });
  }
  themeToggle.addEventListener('click', () => {
    haptic(6);
    theme = theme === 'dark' ? 'light' : 'dark';
    applyTheme(theme); save(K.theme, theme);
  });

  // ---------- Icon registry ----------
  // Each device icon is a sprite symbol id.
  const DEVICE_ICONS = [
    'd-desktop', 'd-laptop', 'd-phone', 'd-server', 'd-home',
    'd-tools', 'd-signal', 'd-game', 'd-film', 'd-box', 'd-lock', 'd-flask',
  ];

  // ---------- Model ----------
  const DEFAULT_DEVICE = {
    icon: 'd-desktop',
    name: 'Desktop',
    host: 'desktop-8r8o6du.tail82cb28.ts.net',
    user: '',
    sshPort: 22,
    rdpPort: 3389,
    webPort: 80,
    notes: '',
    lastUsedAt: 0,
    commands: [],
  };

  let devices = load(K.devices, null);
  if (!Array.isArray(devices)) {
    devices = [{ id: uid(), ...DEFAULT_DEVICE }];
    save(K.devices, devices);
  }
  // Backfill missing fields + migrate emoji icons from v2 to sprite IDs
  const emojiToId = {
    '🖥': 'd-desktop', '💻': 'd-laptop', '📱': 'd-phone',
    '🖲': 'd-server', '🏠': 'd-home',    '🧰': 'd-tools',
    '📡': 'd-signal', '🎮': 'd-game',    '🎬': 'd-film',
    '📦': 'd-box',    '🔒': 'd-lock',    '🧪': 'd-flask',
  };
  devices.forEach(d => {
    if (!d.icon || emojiToId[d.icon]) d.icon = emojiToId[d.icon] || 'd-desktop';
    if (!DEVICE_ICONS.includes(d.icon)) d.icon = 'd-desktop';
    if (typeof d.lastUsedAt !== 'number') d.lastUsedAt = 0;
    if (!Array.isArray(d.commands)) d.commands = [];
  });
  save(K.devices, devices);

  const persist = () => save(K.devices, devices);
  const sortedDevices = () =>
    [...devices].sort((a, b) => (b.lastUsedAt || 0) - (a.lastUsedAt || 0));

  // ---------- Views + transitions ----------
  const homeView = document.getElementById('homeView');
  const deviceView = document.getElementById('deviceView');
  const backBtn = document.getElementById('backBtn');
  const appTitle = document.getElementById('appTitle');
  const appSubtitle = document.getElementById('appSubtitle');

  let currentId = null;
  let inTransition = false;
  const current = () => devices.find(d => d.id === currentId);

  // CSS classes: view--active (on screen), view--prev (slid left, behind),
  // view--next (off right, hidden). Transitions between these animate.
  const goHome = ({ pop = false } = {}) => {
    if (inTransition) return;
    hideSheet(); hideDialog();
    currentId = null;
    save(K.lastDevice, null);
    backBtn.classList.add('hidden');
    appTitle.textContent = 'Remote';
    appSubtitle.textContent = devices.length
      ? 'Tap a device to connect'
      : 'Add a device below to get started';

    inTransition = true;
    homeView.classList.remove('view--prev');
    homeView.classList.add('view--active');
    deviceView.classList.remove('view--active');
    deviceView.classList.add('view--next');
    setTimeout(() => { inTransition = false; }, 300);

    renderHome();
    if (!pop && location.hash) history.replaceState({ page: 'home' }, '', '#');
  };

  const goDevice = (id, { push = true } = {}) => {
    const d = devices.find(x => x.id === id);
    if (!d) return goHome();
    if (inTransition) return;
    hideSheet(); hideDialog();
    currentId = id;
    save(K.lastDevice, id);
    backBtn.classList.remove('hidden');
    appTitle.textContent = d.name || (d.host ? d.host.split('.')[0] : 'Device');
    appSubtitle.textContent = d.host || '';

    renderDevice();

    inTransition = true;
    // Ensure deviceView starts off-screen right, then animate in.
    deviceView.classList.remove('view--next', 'view--prev');
    // Force reflow so the transition plays
    void deviceView.offsetWidth;
    deviceView.classList.add('view--next');
    void deviceView.offsetWidth;
    deviceView.classList.remove('view--next');
    deviceView.classList.add('view--active');
    homeView.classList.remove('view--active');
    homeView.classList.add('view--prev');
    setTimeout(() => { inTransition = false; }, 300);

    if (push) history.pushState({ page: 'device', id }, '', `#${id}`);
  };

  backBtn.addEventListener('click', () => { haptic(6); history.length > 1 ? history.back() : goHome(); });

  // Hardware back / iOS edge swipe → popstate
  window.addEventListener('popstate', (e) => {
    const page = e.state?.page;
    if (page === 'device' && e.state.id) {
      goDevice(e.state.id, { push: false });
    } else {
      goHome({ pop: true });
    }
  });

  // ---------- Home render ----------
  const deviceListEl = document.getElementById('deviceList');
  const addDeviceForm = document.getElementById('addDeviceForm');
  const addDeviceInput = document.getElementById('addDeviceInput');

  const deviceDisplayName = (d) =>
    d.name || (d.host ? d.host.split('.')[0] : 'Untitled device');

  const renderHome = () => {
    deviceListEl.innerHTML = '';

    if (!devices.length) {
      const empty = document.createElement('li');
      empty.className = 'empty-card card';
      empty.innerHTML = `
        <div class="empty-title">No devices yet</div>
        <div class="muted small">Paste a Tailscale hostname below (like <code>my-pc.tailXXXX.ts.net</code>) to add your first device.</div>
      `;
      deviceListEl.appendChild(empty);
      return;
    }

    sortedDevices().forEach(d => {
      const li = document.createElement('li');
      li.className = 'device-card card';
      const shortHost = d.host ? d.host.split('.')[0] : '—';
      const user = (d.user || '').trim();
      const sshTarget = `${user ? user + '@' : ''}${d.host || ''}${(+d.sshPort || 22) !== 22 ? ':' + d.sshPort : ''}`;
      li.innerHTML = `
        <button class="card-tap" aria-label="Open device details">
          <span class="device-avatar">
            <svg class="svg-icon big"><use href="#${d.icon}"/></svg>
          </span>
          <span class="device-main">
            <span class="device-name">${escapeHtml(deviceDisplayName(d))}</span>
            <span class="device-host">${escapeHtml(d.host || 'no hostname set')}</span>
            ${d.lastUsedAt ? `<span class="device-meta">Last used ${escapeHtml(timeAgo(d.lastUsedAt))}</span>` : ''}
          </span>
          <span class="chev">
            <svg class="svg-icon"><use href="#i-chev"/></svg>
          </span>
        </button>
        <div class="quick-actions">
          <button class="quick-btn ssh" data-act="ssh">
            <svg class="svg-icon quick-ico"><use href="#i-ssh"/></svg>
            <span class="quick-text">
              <span class="quick-label">SSH</span>
              <span class="quick-sub">${escapeHtml(sshTarget || shortHost)}</span>
            </span>
          </button>
          <button class="quick-btn rdp" data-act="rdp">
            <svg class="svg-icon quick-ico"><use href="#i-rdp"/></svg>
            <span class="quick-text">
              <span class="quick-label">RDP</span>
              <span class="quick-sub">${escapeHtml(shortHost)}</span>
            </span>
          </button>
          <button class="quick-btn copy" data-act="copy" aria-label="Copy ssh command">
            <svg class="svg-icon quick-ico"><use href="#i-copy"/></svg>
          </button>
        </div>
      `;
      li.querySelector('.card-tap').addEventListener('click', () => { haptic(8); goDevice(d.id); });
      li.querySelectorAll('.quick-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
          e.stopPropagation();
          haptic(10);
          const act = btn.dataset.act;
          if (act === 'ssh') doSsh(d);
          else if (act === 'rdp') doRdp(d);
          else if (act === 'copy') doCopy(d);
        });
      });
      deviceListEl.appendChild(li);
    });
  };

  addDeviceForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const raw = addDeviceInput.value.trim();
    if (!raw) return;
    haptic(10);
    const host = raw.replace(/^https?:\/\//i, '').replace(/\/.*$/, '');
    const d = {
      id: uid(),
      icon: 'd-desktop',
      name: host.split('.')[0] || 'Device',
      host,
      user: '',
      sshPort: 22,
      rdpPort: 3389,
      webPort: 80,
      notes: '',
      lastUsedAt: 0,
      commands: [],
    };
    devices.push(d);
    persist();
    addDeviceInput.value = '';
    goDevice(d.id);
  });

  // ---------- Device render ----------
  const dName = document.getElementById('dName');
  const dHost = document.getElementById('dHost');
  const dUser = document.getElementById('dUser');
  const dSshPort = document.getElementById('dSshPort');
  const dRdpPort = document.getElementById('dRdpPort');
  const dWebPort = document.getElementById('dWebPort');
  const dNotes = document.getElementById('dNotes');
  const deleteDeviceBtn = document.getElementById('deleteDeviceBtn');
  const sshBtn = document.getElementById('sshBtn');
  const rdpBtn = document.getElementById('rdpBtn');
  const copyBtn = document.getElementById('copyBtn');
  const webBtn = document.getElementById('webBtn');
  const sshSub = document.getElementById('sshSub');
  const rdpSub = document.getElementById('rdpSub');
  const copySub = document.getElementById('copySub');
  const webSub = document.getElementById('webSub');
  const cmdList = document.getElementById('cmdList');
  const cmdCount = document.getElementById('cmdCount');
  const addCmdForm = document.getElementById('addCmdForm');
  const cmdName = document.getElementById('cmdName');
  const cmdBody = document.getElementById('cmdBody');
  const iconBtn = document.getElementById('iconBtn');
  const currentDeviceIconUse = document.getElementById('currentDeviceIconUse');

  const renderDevice = () => {
    const d = current();
    if (!d) return goHome();
    dName.value = d.name || '';
    dHost.value = d.host || '';
    dUser.value = d.user || '';
    dSshPort.value = d.sshPort ?? '';
    dRdpPort.value = d.rdpPort ?? '';
    dWebPort.value = d.webPort ?? '';
    dNotes.value = d.notes || '';
    currentDeviceIconUse.setAttribute('href', '#' + (d.icon || 'd-desktop'));
    renderSubs();
    renderCommands();
  };

  const renderSubs = () => {
    const d = current(); if (!d) return;
    const user = (d.user || '').trim();
    const host = (d.host || '').trim();
    const sshPort = +d.sshPort || 22;
    const rdpPort = +d.rdpPort || 3389;
    const webPort = +d.webPort || 80;
    sshSub.textContent = host ? `${user ? user + '@' : ''}${host}${sshPort !== 22 ? ':' + sshPort : ''}` : 'set hostname';
    rdpSub.textContent = host ? `${host}${rdpPort !== 3389 ? ':' + rdpPort : ''}` : 'set hostname';
    copySub.textContent = host ? `ssh ${user ? user + '@' : ''}${host}` : 'set hostname';
    webSub.textContent = host ? `http://${host}${webPort !== 80 ? ':' + webPort : ''}` : 'set hostname';
  };

  // ---------- Bottom sheet (icon picker) ----------
  const sheetBackdrop = document.getElementById('sheetBackdrop');
  const iconSheet = document.getElementById('iconSheet');
  const iconPicker = document.getElementById('iconPicker');
  const sheetClose = document.getElementById('sheetClose');

  const renderIconGrid = () => {
    const d = current();
    iconPicker.innerHTML = '';
    DEVICE_ICONS.forEach(id => {
      const b = document.createElement('button');
      b.type = 'button';
      b.className = 'icon-swatch' + (d && d.icon === id ? ' selected' : '');
      b.innerHTML = `<svg class="svg-icon big"><use href="#${id}"/></svg>`;
      b.setAttribute('role', 'option');
      b.addEventListener('click', () => {
        haptic(10);
        if (current()) {
          current().icon = id;
          persist();
          currentDeviceIconUse.setAttribute('href', '#' + id);
        }
        hideSheet();
      });
      iconPicker.appendChild(b);
    });
  };

  const showSheet = () => {
    renderIconGrid();
    sheetBackdrop.classList.remove('hidden');
    iconSheet.classList.remove('hidden');
    requestAnimationFrame(() => {
      sheetBackdrop.classList.add('shown');
      iconSheet.classList.add('shown');
    });
  };
  const hideSheet = () => {
    sheetBackdrop.classList.remove('shown');
    iconSheet.classList.remove('shown');
    setTimeout(() => {
      sheetBackdrop.classList.add('hidden');
      iconSheet.classList.add('hidden');
    }, 240);
  };
  iconBtn.addEventListener('click', (e) => { e.stopPropagation(); haptic(8); showSheet(); });
  sheetBackdrop.addEventListener('click', hideSheet);
  sheetClose.addEventListener('click', hideSheet);

  // ---------- Custom confirm dialog ----------
  const dialogBackdrop = document.getElementById('dialogBackdrop');
  const dialog = document.getElementById('dialog');
  const dialogTitle = document.getElementById('dialogTitle');
  const dialogBody = document.getElementById('dialogBody');
  const dialogConfirm = document.getElementById('dialogConfirm');
  const dialogCancel = document.getElementById('dialogCancel');

  const showDialog = ({ title, body, confirmText = 'OK', cancelText = 'Cancel', danger = false }) => {
    return new Promise(resolve => {
      dialogTitle.textContent = title || '';
      dialogBody.textContent = body || '';
      dialogConfirm.textContent = confirmText;
      dialogCancel.textContent = cancelText;
      dialogConfirm.classList.toggle('danger', !!danger);

      const cleanup = (value) => {
        dialogConfirm.removeEventListener('click', onOk);
        dialogCancel.removeEventListener('click', onCancel);
        dialogBackdrop.removeEventListener('click', onCancel);
        hideDialog();
        resolve(value);
      };
      const onOk = () => { haptic(danger ? 16 : 8); cleanup(true); };
      const onCancel = () => { haptic(4); cleanup(false); };

      dialogConfirm.addEventListener('click', onOk);
      dialogCancel.addEventListener('click', onCancel);
      dialogBackdrop.addEventListener('click', onCancel);

      dialogBackdrop.classList.remove('hidden');
      dialog.classList.remove('hidden');
      requestAnimationFrame(() => {
        dialogBackdrop.classList.add('shown');
        dialog.classList.add('shown');
      });
    });
  };
  const hideDialog = () => {
    dialogBackdrop.classList.remove('shown');
    dialog.classList.remove('shown');
    setTimeout(() => {
      dialogBackdrop.classList.add('hidden');
      dialog.classList.add('hidden');
    }, 200);
  };

  // ---------- Field bindings ----------
  const bindField = (el, key, coerce = (v) => v) => {
    el.addEventListener('input', () => {
      const d = current(); if (!d) return;
      d[key] = coerce(el.value);
      persist();
      if (key === 'name' || key === 'host') {
        appTitle.textContent = d.name || (d.host ? d.host.split('.')[0] : 'Device');
        if (key === 'host') appSubtitle.textContent = d.host || '';
      }
      renderSubs();
    });
  };
  const numOrBlank = (v) => v === '' ? '' : (+v);
  bindField(dName, 'name');
  bindField(dHost, 'host', v => v.trim());
  bindField(dUser, 'user', v => v.trim());
  bindField(dSshPort, 'sshPort', numOrBlank);
  bindField(dRdpPort, 'rdpPort', numOrBlank);
  bindField(dWebPort, 'webPort', numOrBlank);
  bindField(dNotes, 'notes');

  deleteDeviceBtn.addEventListener('click', async () => {
    const d = current(); if (!d) return;
    haptic(12);
    const ok = await showDialog({
      title: 'Delete device',
      body: `Delete "${deviceDisplayName(d)}" and all its saved commands? This can't be undone.`,
      confirmText: 'Delete',
      danger: true,
    });
    if (!ok) return;
    devices = devices.filter(x => x.id !== d.id);
    persist();
    history.length > 1 ? history.back() : goHome();
  });

  // ---------- Launch actions ----------
  const touchLastUsed = (d) => { d.lastUsedAt = Date.now(); persist(); };
  const missingHost = (d) => {
    if (!d.host) { toast('Set a hostname first', '#i-trash'); return true; }
    return false;
  };

  const doSsh = (d) => {
    if (missingHost(d)) return;
    const user = (d.user || '').trim();
    const port = +d.sshPort || 22;
    const url = `ssh://${user ? encodeURIComponent(user) + '@' : ''}${d.host}${port !== 22 ? ':' + port : ''}`;
    touchLastUsed(d);
    launchScheme(url, 'SSH app');
  };

  const doRdp = (d) => {
    if (missingHost(d)) return;
    const port = +d.rdpPort || 3389;
    const user = (d.user || '').trim();
    const parts = [`full%20address=s:${encodeURIComponent(d.host + ':' + port)}`];
    if (user) parts.push(`username=s:${encodeURIComponent(user)}`);
    const url = `rdp://${parts.join('&')}`;
    touchLastUsed(d);
    launchScheme(url, 'Remote Desktop');
  };

  const doCopy = async (d) => {
    if (missingHost(d)) return;
    const user = (d.user || '').trim();
    const port = +d.sshPort || 22;
    const cmd = `ssh ${user ? user + '@' : ''}${d.host}${port !== 22 ? ' -p ' + port : ''}`;
    await copyToClipboard(cmd);
    touchLastUsed(d);
    toast('Copied: ' + cmd);
  };

  const doWeb = (d) => {
    if (missingHost(d)) return;
    const port = +d.webPort || 80;
    const url = `http://${d.host}${port !== 80 ? ':' + port : ''}/`;
    touchLastUsed(d);
    window.open(url, '_blank', 'noopener');
  };

  sshBtn.addEventListener('click', () => { const d = current(); if (d) { haptic(12); doSsh(d); } });
  rdpBtn.addEventListener('click', () => { const d = current(); if (d) { haptic(12); doRdp(d); } });
  copyBtn.addEventListener('click', () => { const d = current(); if (d) { haptic(10); doCopy(d); } });
  webBtn.addEventListener('click', () => { const d = current(); if (d) { haptic(10); doWeb(d); } });

  const launchScheme = (url, label) => {
    let left = false;
    const onHide = () => { left = true; };
    document.addEventListener('visibilitychange', onHide, { once: true });
    window.location.href = url;
    setTimeout(() => {
      document.removeEventListener('visibilitychange', onHide);
      if (!left && document.visibilityState === 'visible') {
        toast(`No ${label} installed`);
      }
    }, 1800);
  };

  const copyToClipboard = async (text) => {
    try { await navigator.clipboard.writeText(text); }
    catch {
      const ta = document.createElement('textarea');
      ta.value = text;
      ta.style.position = 'fixed';
      ta.style.opacity = '0';
      document.body.appendChild(ta);
      ta.select();
      try { document.execCommand('copy'); } catch {}
      document.body.removeChild(ta);
    }
  };
  const readFromClipboard = async () => {
    try { return await navigator.clipboard.readText(); } catch { return null; }
  };

  // ---------- Saved commands ----------
  const renderCommands = () => {
    const d = current(); if (!d) return;
    cmdList.innerHTML = '';
    cmdCount.textContent = String((d.commands || []).length);
    if (!d.commands?.length) {
      const li = document.createElement('li');
      li.className = 'empty';
      li.textContent = 'No saved commands yet.';
      cmdList.appendChild(li);
      return;
    }
    d.commands.forEach(c => {
      const li = document.createElement('li');
      li.className = 'cmd-item';
      li.innerHTML = `
        <div class="cmd-main">
          <div class="cmd-name">${escapeHtml(c.name || 'command')}</div>
          <div class="cmd-body muted small">${escapeHtml(c.body || '')}</div>
        </div>
        <button class="delete-btn" aria-label="Delete">
          <svg class="svg-icon"><use href="#i-trash"/></svg>
        </button>
      `;
      li.querySelector('.cmd-main').addEventListener('click', async () => {
        haptic(8);
        await copyToClipboard(c.body || '');
        toast('Copied');
      });
      li.querySelector('.delete-btn').addEventListener('click', async (e) => {
        e.stopPropagation();
        haptic(10);
        const ok = await showDialog({
          title: 'Delete command',
          body: `Delete "${c.name || 'this command'}"?`,
          confirmText: 'Delete',
          danger: true,
        });
        if (!ok) return;
        d.commands = (d.commands || []).filter(x => x.id !== c.id);
        persist();
        renderCommands();
      });
      cmdList.appendChild(li);
    });
  };

  addCmdForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const d = current(); if (!d) return;
    const name = cmdName.value.trim();
    const body = cmdBody.value.trim();
    if (!body) return;
    haptic(8);
    d.commands = d.commands || [];
    d.commands.push({ id: uid(), name: name || body.slice(0, 24), body });
    persist();
    cmdName.value = ''; cmdBody.value = '';
    renderCommands();
  });

  // ---------- Backup ----------
  document.getElementById('exportBtn').addEventListener('click', async () => {
    haptic(8);
    const blob = { version: 3, exportedAt: new Date().toISOString(), devices };
    await copyToClipboard(JSON.stringify(blob, null, 2));
    toast(`Exported ${devices.length} device${devices.length === 1 ? '' : 's'} to clipboard`);
  });
  document.getElementById('importBtn').addEventListener('click', async () => {
    haptic(8);
    const text = await readFromClipboard();
    if (!text) { toast('Could not read clipboard'); return; }
    let parsed;
    try { parsed = JSON.parse(text); } catch { toast('Clipboard is not JSON'); return; }
    const incoming = Array.isArray(parsed) ? parsed : parsed?.devices;
    if (!Array.isArray(incoming)) { toast('No devices array in clipboard'); return; }
    const ok = await showDialog({
      title: 'Replace devices?',
      body: `Replace your ${devices.length} device${devices.length === 1 ? '' : 's'} with ${incoming.length} from clipboard? This can't be undone.`,
      confirmText: 'Replace',
      danger: true,
    });
    if (!ok) return;
    devices = incoming.map(d => ({
      id: d.id || uid(),
      icon: DEVICE_ICONS.includes(d.icon) ? d.icon : (emojiToId[d.icon] || 'd-desktop'),
      name: d.name || '',
      host: d.host || '',
      user: d.user || '',
      sshPort: d.sshPort ?? 22,
      rdpPort: d.rdpPort ?? 3389,
      webPort: d.webPort ?? 80,
      notes: d.notes || '',
      lastUsedAt: typeof d.lastUsedAt === 'number' ? d.lastUsedAt : 0,
      commands: Array.isArray(d.commands) ? d.commands : [],
    }));
    persist();
    toast(`Imported ${devices.length} device${devices.length === 1 ? '' : 's'}`);
    goHome();
  });

  // ---------- Toast ----------
  const toastEl = document.getElementById('toast');
  const toastText = document.getElementById('toastText');
  const toastIconUse = document.getElementById('toastIconUse');
  let toastTimer;
  function toast(msg, iconHref = '#i-check') {
    toastIconUse.setAttribute('href', iconHref);
    toastText.textContent = msg;
    toastEl.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toastEl.classList.remove('show'), 2000);
  }

  // ---------- Utils ----------
  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, c => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    }[c]));
  }
  function timeAgo(ts) {
    if (!ts) return '';
    const d = Date.now() - ts;
    if (d < 30_000) return 'just now';
    if (d < 3_600_000) return Math.floor(d / 60_000) + 'm ago';
    if (d < 86_400_000) return Math.floor(d / 3_600_000) + 'h ago';
    if (d < 7 * 86_400_000) return Math.floor(d / 86_400_000) + 'd ago';
    return new Date(ts).toLocaleDateString();
  }

  // ---------- Shortcut-link chips (device detail) ----------
  // Generates a deep-link URL that the user can stick in iOS Shortcuts.
  document.querySelectorAll('[data-link]').forEach(btn => {
    btn.addEventListener('click', async () => {
      const d = current(); if (!d) return;
      haptic(10);
      const action = btn.dataset.link;
      const url = `${location.origin}${location.pathname}?go=${action}&id=${encodeURIComponent(d.id)}`;
      await copyToClipboard(url);
      toast('Link copied — paste into iOS Shortcuts');
    });
  });

  // ---------- Deep links (?go=<action>&id=<id>) ----------
  // Runs an action automatically on load, then clears the query so a
  // reload doesn't re-fire. Intended for iOS Shortcuts / home-screen shortcuts.
  const runDeepLink = () => {
    const p = new URLSearchParams(location.search);
    const action = p.get('go');
    const id = p.get('id');
    if (!action || !id) return false;
    const d = devices.find(x => x.id === id);
    if (!d) { toast('Device not found'); }
    else {
      switch (action) {
        case 'ssh':  doSsh(d);  break;
        case 'rdp':  doRdp(d);  break;
        case 'copy': doCopy(d); break;
        case 'web':  doWeb(d);  break;
        default:     toast('Unknown action: ' + action); break;
      }
    }
    // Clean the URL so reloads don't re-trigger
    history.replaceState({ page: 'home' }, '', location.pathname);
    return true;
  };

  // ---------- Boot ----------
  // Deep-link first: if ?go=<action>&id=<id> is present, render home and run it.
  const hadDeepLink = runDeepLink();

  // Initial state: derive from location.hash if present, else last-visited.
  const hashId = location.hash ? location.hash.slice(1) : '';
  const bootId = hadDeepLink
    ? null
    : (hashId && devices.some(d => d.id === hashId))
      ? hashId
      : ((id) => id && devices.some(d => d.id === id) ? id : null)(load(K.lastDevice, null));

  if (bootId) {
    // Render home first (without transition), then show device without animation.
    renderHome();
    currentId = bootId;
    renderDevice();
    homeView.classList.remove('view--active');
    homeView.classList.add('view--prev');
    deviceView.classList.remove('view--next');
    deviceView.classList.add('view--active');
    backBtn.classList.remove('hidden');
    const d = current();
    if (d) { appTitle.textContent = d.name || d.host; appSubtitle.textContent = d.host || ''; }
    history.replaceState({ page: 'device', id: bootId }, '', `#${bootId}`);
  } else {
    renderHome();
    history.replaceState({ page: 'home' }, '', '#');
  }

  // ---------- Service worker ----------
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('sw.js').catch(() => {});
    });
  }

  // Listen for SW-driven reload hints
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.addEventListener('message', e => {
      if (e.data?.type === 'RELOAD') location.reload();
    });
  }
})();
