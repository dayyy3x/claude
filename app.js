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
  const applyTheme = (t) => {
    document.documentElement.setAttribute('data-theme', t);
    const meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute('content', t === 'light' ? '#f4f6fb' : '#0b1020');
  };
  let theme = load(K.theme, 'dark');
  applyTheme(theme);
  themeToggle.addEventListener('click', () => {
    theme = theme === 'dark' ? 'light' : 'dark';
    applyTheme(theme); save(K.theme, theme);
  });

  // ---------- Model ----------
  // Device: { id, name, host, user, sshPort, rdpPort, webPort, notes,
  //           commands: [{ id, name, body }] }
  const DEFAULT_DEVICE = {
    name: 'Desktop',
    host: 'desktop-8r8o6du.tail82cb28.ts.net',
    user: '',
    sshPort: 22,
    rdpPort: 3389,
    webPort: 80,
    notes: '',
    commands: [],
  };

  let devices = load(K.devices, null);
  if (!Array.isArray(devices)) {
    devices = [{ id: uid(), ...DEFAULT_DEVICE }];
    save(K.devices, devices);
  }
  const persist = () => save(K.devices, devices);

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
    appTitle.textContent = 'Remote';
    appSubtitle.textContent = devices.length
      ? 'Tap a device to connect'
      : 'Add a device below to get started';
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
    appTitle.textContent = d.name || d.host || 'Device';
    appSubtitle.textContent = d.host || '';
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
        <div class="muted small">Add the Tailscale hostname of a device (like <code>my-pc.tailXXXX.ts.net</code>) to get one-tap SSH / RDP shortcuts.</div>
      `;
      deviceListEl.appendChild(empty);
      return;
    }

    devices.forEach(d => {
      const li = document.createElement('li');
      li.className = 'device-card card';
      const shortHost = d.host ? d.host.split('.')[0] : '—';
      li.innerHTML = `
        <div class="device-main">
          <div class="device-name">${escapeHtml(deviceDisplayName(d))}</div>
          <div class="device-host muted small">${escapeHtml(d.host || 'no hostname set')}</div>
        </div>
        <div class="device-side">
          <div class="device-badge">${escapeHtml(shortHost)}</div>
        </div>
      `;
      li.addEventListener('click', () => showDevice(d.id));
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
      name: host.split('.')[0] || 'Device',
      host,
      user: '',
      sshPort: 22,
      rdpPort: 3389,
      webPort: 80,
      notes: '',
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

  // ---------- Launch actions ----------
  const missingHost = (d) => {
    if (!d.host) { toast('Set a hostname first'); return true; }
    return false;
  };

  sshBtn.addEventListener('click', () => {
    const d = current(); if (!d || missingHost(d)) return;
    const user = (d.user || '').trim();
    const port = +d.sshPort || 22;
    // Termius and Blink both register ssh:// — send user, host, and port.
    const url = `ssh://${user ? encodeURIComponent(user) + '@' : ''}${d.host}${port !== 22 ? ':' + port : ''}`;
    launchScheme(url, 'SSH app');
  });

  rdpBtn.addEventListener('click', () => {
    const d = current(); if (!d || missingHost(d)) return;
    const port = +d.rdpPort || 3389;
    const user = (d.user || '').trim();
    // Microsoft Remote Desktop (iOS/Android) supports rdp:// URLs with
    // .rdp-style key=value fields, URL-encoded.
    const parts = [
      `full%20address=s:${encodeURIComponent(d.host + ':' + port)}`,
    ];
    if (user) parts.push(`username=s:${encodeURIComponent(user)}`);
    const url = `rdp://${parts.join('&')}`;
    launchScheme(url, 'Remote Desktop');
  });

  copyBtn.addEventListener('click', async () => {
    const d = current(); if (!d || missingHost(d)) return;
    const user = (d.user || '').trim();
    const port = +d.sshPort || 22;
    const cmd = `ssh ${user ? user + '@' : ''}${d.host}${port !== 22 ? ' -p ' + port : ''}`;
    await copyToClipboard(cmd);
    toast('Copied: ' + cmd);
  });

  webBtn.addEventListener('click', () => {
    const d = current(); if (!d || missingHost(d)) return;
    const port = +d.webPort || 80;
    const url = `http://${d.host}${port !== 80 ? ':' + port : ''}/`;
    window.open(url, '_blank', 'noopener');
  });

  const launchScheme = (url, label) => {
    // Track whether we end up backgrounded. If the scheme resolves, iOS/Android
    // hands off to the app and we lose focus. Otherwise, show a tip.
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
      // Fallback for older browsers / non-HTTPS contexts
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
