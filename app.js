/* Mobile remote-access launcher — vanilla JS, saves to localStorage. */
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

  // ---------- Theme ----------
  const themeToggle = document.getElementById('themeToggle');
  const systemPrefersDark = () =>
    window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
  const applyTheme = (t) => {
    document.documentElement.setAttribute('data-theme', t);
    const meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute('content', t === 'light' ? '#f4f6fb' : '#0b1020');
  };
  // If the user has never picked a theme, follow the system preference.
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
    theme = theme === 'dark' ? 'light' : 'dark';
    applyTheme(theme); save(K.theme, theme);
  });

  // ---------- Model ----------
  // Device: { id, icon, name, host, user, sshPort, rdpPort, webPort, notes,
  //           lastUsedAt, commands: [{ id, name, body }] }
  const DEFAULT_DEVICE = {
    icon: '🖥',
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

  const ICONS = ['🖥', '💻', '📱', '🖲', '🏠', '🧰', '📡', '🎮', '🎬', '📦', '🔒', '🧪'];

  let devices = load(K.devices, null);
  if (!Array.isArray(devices)) {
    devices = [{ id: uid(), ...DEFAULT_DEVICE }];
    save(K.devices, devices);
  }
  // Backfill any missing fields on pre-v2 data
  devices.forEach(d => {
    if (!d.icon) d.icon = '🖥';
    if (typeof d.lastUsedAt !== 'number') d.lastUsedAt = 0;
    if (!Array.isArray(d.commands)) d.commands = [];
  });
  const persist = () => save(K.devices, devices);

  // Derived: sorted view (most recently launched first; untouched keep insertion order)
  const sortedDevices = () =>
    [...devices].sort((a, b) => (b.lastUsedAt || 0) - (a.lastUsedAt || 0));

  // ---------- Views ----------
  const homeView = document.getElementById('homeView');
  const deviceView = document.getElementById('deviceView');
  const backBtn = document.getElementById('backBtn');
  const appTitle = document.getElementById('appTitle');
  const appSubtitle = document.getElementById('appSubtitle');

  let currentId = null;
  const current = () => devices.find(d => d.id === currentId);

  const showHome = () => {
    currentId = null;
    save(K.lastDevice, null);
    homeView.classList.remove('hidden');
    deviceView.classList.add('hidden');
    backBtn.classList.add('hidden');
    appTitle.innerHTML = 'Remote <span class="ver-badge">v2</span>';
    appSubtitle.textContent = devices.length
      ? 'Tap a device to connect'
      : 'Add a device below to get started';
    hideIconPicker();
    renderHome();
  };

  const showDevice = (id) => {
    const d = devices.find(x => x.id === id);
    if (!d) return showHome();
    currentId = id;
    save(K.lastDevice, id);
    homeView.classList.add('hidden');
    deviceView.classList.remove('hidden');
    backBtn.classList.remove('hidden');
    appTitle.textContent = d.name || (d.host ? d.host.split('.')[0] : 'Device');
    appSubtitle.textContent = d.host || '';
    hideIconPicker();
    renderDevice();
  };

  backBtn.addEventListener('click', showHome);

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
        <div class="muted small">Paste a Tailscale hostname below to add your first device (like <code>my-pc.tailXXXX.ts.net</code>). You'll get one-tap SSH, RDP, and web shortcuts.</div>
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
          <div class="device-avatar">${escapeHtml(d.icon || '🖥')}</div>
          <div class="device-main">
            <div class="device-name">${escapeHtml(deviceDisplayName(d))}</div>
            <div class="device-host muted small">${escapeHtml(d.host || 'no hostname set')}</div>
          </div>
          <div class="chev" aria-hidden="true">›</div>
        </button>
        <div class="quick-actions">
          <button class="quick-btn ssh" data-act="ssh">
            <span class="quick-icon">⌨</span>
            <span class="quick-text">
              <span class="quick-label">SSH</span>
              <span class="quick-sub">${escapeHtml(sshTarget || shortHost)}</span>
            </span>
          </button>
          <button class="quick-btn rdp" data-act="rdp">
            <span class="quick-icon">🖥</span>
            <span class="quick-text">
              <span class="quick-label">RDP</span>
              <span class="quick-sub">${escapeHtml(shortHost)}</span>
            </span>
          </button>
          <button class="quick-btn copy" data-act="copy" aria-label="Copy ssh command">
            <span class="quick-icon">⎘</span>
          </button>
        </div>
      `;
      li.querySelector('.card-tap').addEventListener('click', () => showDevice(d.id));
      li.querySelectorAll('.quick-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
          e.stopPropagation();
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
    const host = raw.replace(/^https?:\/\//i, '').replace(/\/.*$/, '');
    const d = {
      id: uid(),
      icon: '🖥',
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
    showDevice(d.id);
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
  const iconCurrent = document.getElementById('iconCurrent');
  const iconPicker = document.getElementById('iconPicker');

  const renderDevice = () => {
    const d = current();
    if (!d) return showHome();
    dName.value = d.name || '';
    dHost.value = d.host || '';
    dUser.value = d.user || '';
    dSshPort.value = d.sshPort ?? '';
    dRdpPort.value = d.rdpPort ?? '';
    dWebPort.value = d.webPort ?? '';
    dNotes.value = d.notes || '';
    iconCurrent.textContent = d.icon || '🖥';
    renderSubs();
    renderCommands();
    renderIconPicker();
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

  const renderIconPicker = () => {
    const d = current(); if (!d) return;
    iconPicker.innerHTML = '';
    ICONS.forEach(ic => {
      const b = document.createElement('button');
      b.type = 'button';
      b.className = 'icon-swatch' + (d.icon === ic ? ' selected' : '');
      b.textContent = ic;
      b.setAttribute('role', 'option');
      b.setAttribute('aria-selected', d.icon === ic ? 'true' : 'false');
      b.addEventListener('click', () => {
        d.icon = ic;
        persist();
        iconCurrent.textContent = ic;
        renderIconPicker();
        hideIconPicker();
      });
      iconPicker.appendChild(b);
    });
  };
  const hideIconPicker = () => iconPicker.classList.add('hidden');
  iconBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    iconPicker.classList.toggle('hidden');
  });
  document.addEventListener('click', (e) => {
    if (iconPicker.classList.contains('hidden')) return;
    if (e.target.closest('#iconPicker') || e.target.closest('#iconBtn')) return;
    hideIconPicker();
  });

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

  deleteDeviceBtn.addEventListener('click', () => {
    const d = current(); if (!d) return;
    const ok = confirm(`Delete "${deviceDisplayName(d)}"?`);
    if (!ok) return;
    devices = devices.filter(x => x.id !== d.id);
    persist();
    showHome();
  });

  // ---------- Launch actions (shared between home cards and detail view) ----------
  const touchLastUsed = (d) => {
    d.lastUsedAt = Date.now();
    persist();
  };
  const missingHost = (d) => {
    if (!d.host) { toast('Set a hostname first'); return true; }
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

  sshBtn.addEventListener('click', () => { const d = current(); if (d) doSsh(d); });
  rdpBtn.addEventListener('click', () => { const d = current(); if (d) doRdp(d); });
  copyBtn.addEventListener('click', () => { const d = current(); if (d) doCopy(d); });
  webBtn.addEventListener('click', () => { const d = current(); if (d) doWeb(d); });

  const launchScheme = (url, label) => {
    let left = false;
    const onHide = () => { left = true; };
    document.addEventListener('visibilitychange', onHide, { once: true });
    window.location.href = url;
    setTimeout(() => {
      document.removeEventListener('visibilitychange', onHide);
      if (!left && document.visibilityState === 'visible') {
        toast(`No ${label} installed — install one and try again`);
      }
    }, 1800);
  };

  const copyToClipboard = async (text) => {
    try {
      await navigator.clipboard.writeText(text);
    } catch {
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
    try { return await navigator.clipboard.readText(); }
    catch { return null; }
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
        <button class="delete-btn" aria-label="Delete">×</button>
      `;
      li.querySelector('.cmd-main').addEventListener('click', async () => {
        await copyToClipboard(c.body || '');
        toast('Copied');
      });
      li.querySelector('.delete-btn').addEventListener('click', (e) => {
        e.stopPropagation();
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
    d.commands = d.commands || [];
    d.commands.push({ id: uid(), name: name || body.slice(0, 24), body });
    persist();
    cmdName.value = ''; cmdBody.value = '';
    renderCommands();
  });

  // ---------- Backup (export / import) ----------
  document.getElementById('exportBtn').addEventListener('click', async () => {
    const blob = { version: 2, exportedAt: new Date().toISOString(), devices };
    await copyToClipboard(JSON.stringify(blob, null, 2));
    toast(`Exported ${devices.length} device${devices.length === 1 ? '' : 's'} to clipboard`);
  });
  document.getElementById('importBtn').addEventListener('click', async () => {
    const text = await readFromClipboard();
    if (!text) { toast('Could not read clipboard'); return; }
    let parsed;
    try { parsed = JSON.parse(text); } catch { toast('Clipboard is not JSON'); return; }
    const incoming = Array.isArray(parsed) ? parsed : parsed?.devices;
    if (!Array.isArray(incoming)) { toast('No devices array in clipboard'); return; }
    if (!confirm(`Replace your ${devices.length} device${devices.length === 1 ? '' : 's'} with ${incoming.length} from clipboard?`)) return;
    devices = incoming.map(d => ({
      id: d.id || uid(),
      icon: d.icon || '🖥',
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
    showHome();
  });

  // ---------- Toast ----------
  const toastEl = document.getElementById('toast');
  let toastTimer;
  const toast = (msg) => {
    toastEl.textContent = msg;
    toastEl.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toastEl.classList.remove('show'), 2200);
  };

  // ---------- Utils ----------
  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, c => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    }[c]));
  }

  // ---------- Boot ----------
  const lastId = load(K.lastDevice, null);
  if (lastId && devices.some(d => d.id === lastId)) {
    showDevice(lastId);
  } else {
    showHome();
  }

  // ---------- Service worker ----------
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('sw.js').catch(() => {});
    });
  }
})();
