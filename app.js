/* Mobile dashboard app — vanilla JS, persists to localStorage */
(() => {
  'use strict';

  // ---------- Storage helpers ----------
  const K = {
    name: 'db_name',
    theme: 'db_theme',
    todos: 'db_todos',
    habits: 'db_habits',
    notes: 'db_notes',
    stats: 'db_stats',
    weather: 'db_weather_cache',
  };
  const load = (k, fallback) => {
    try {
      const v = localStorage.getItem(k);
      return v == null ? fallback : JSON.parse(v);
    } catch { return fallback; }
  };
  const save = (k, v) => {
    try { localStorage.setItem(k, JSON.stringify(v)); } catch {}
  };

  const uid = () => Math.random().toString(36).slice(2, 10);
  const todayKey = () => new Date().toISOString().slice(0, 10);

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
    applyTheme(theme);
    save(K.theme, theme);
  });

  // ---------- Greeting + name ----------
  const greetingEl = document.getElementById('greeting');
  const nameEl = document.getElementById('userName');
  nameEl.textContent = load(K.name, 'friend');
  const updateGreeting = () => {
    const h = new Date().getHours();
    greetingEl.textContent =
      h < 5 ? 'Still up,' :
      h < 12 ? 'Good morning,' :
      h < 17 ? 'Good afternoon,' :
      h < 22 ? 'Good evening,' : 'Good night,';
  };
  updateGreeting();
  nameEl.addEventListener('blur', () => {
    const v = nameEl.textContent.trim() || 'friend';
    nameEl.textContent = v;
    save(K.name, v);
  });
  nameEl.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') { e.preventDefault(); nameEl.blur(); }
  });

  // ---------- Clock ----------
  const clockEl = document.getElementById('clock');
  const dateEl = document.getElementById('date');
  const tickClock = () => {
    const now = new Date();
    const hh = String(now.getHours()).padStart(2, '0');
    const mm = String(now.getMinutes()).padStart(2, '0');
    clockEl.textContent = `${hh}:${mm}`;
    dateEl.textContent = now.toLocaleDateString(undefined, {
      weekday: 'long', month: 'long', day: 'numeric',
    });
    updateGreeting();
  };
  tickClock();
  setInterval(tickClock, 1000 * 30);

  // ---------- Weather (Open-Meteo, no API key) ----------
  const tempEl = document.getElementById('temp');
  const descEl = document.getElementById('weatherDesc');
  const locEl = document.getElementById('weatherLoc');
  const iconEl = document.getElementById('weatherIcon');
  const refreshBtn = document.getElementById('refreshWeather');

  const wmoMap = {
    0: ['Clear sky', '☀️'],
    1: ['Mainly clear', '🌤️'],
    2: ['Partly cloudy', '⛅'],
    3: ['Overcast', '☁️'],
    45: ['Fog', '🌫️'], 48: ['Rime fog', '🌫️'],
    51: ['Light drizzle', '🌦️'], 53: ['Drizzle', '🌦️'], 55: ['Heavy drizzle', '🌧️'],
    61: ['Light rain', '🌦️'], 63: ['Rain', '🌧️'], 65: ['Heavy rain', '🌧️'],
    66: ['Freezing rain', '🌧️'], 67: ['Freezing rain', '🌧️'],
    71: ['Light snow', '🌨️'], 73: ['Snow', '🌨️'], 75: ['Heavy snow', '❄️'],
    77: ['Snow grains', '🌨️'],
    80: ['Rain showers', '🌦️'], 81: ['Rain showers', '🌧️'], 82: ['Heavy showers', '⛈️'],
    85: ['Snow showers', '🌨️'], 86: ['Snow showers', '❄️'],
    95: ['Thunderstorm', '⛈️'], 96: ['Thunderstorm', '⛈️'], 99: ['Thunderstorm', '⛈️'],
  };

  const renderWeather = (data) => {
    if (!data) return;
    const [desc, icon] = wmoMap[data.code] || ['—', '🌡️'];
    tempEl.textContent = `${Math.round(data.temp)}°${data.unit || 'C'}`;
    descEl.textContent = desc;
    iconEl.textContent = icon;
    locEl.textContent = data.place
      ? `${data.place} · updated ${new Date(data.ts).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`
      : `updated ${new Date(data.ts).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;
  };

  const fetchWeather = async () => {
    descEl.textContent = 'Locating…';
    if (!('geolocation' in navigator)) {
      descEl.textContent = 'Geolocation not supported';
      return;
    }
    try {
      const pos = await new Promise((res, rej) => {
        navigator.geolocation.getCurrentPosition(res, rej, {
          enableHighAccuracy: false, timeout: 10000, maximumAge: 5 * 60 * 1000,
        });
      });
      const { latitude: lat, longitude: lon } = pos.coords;
      descEl.textContent = 'Fetching…';
      const res = await fetch(
        `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,weather_code&temperature_unit=celsius`
      );
      if (!res.ok) throw new Error('Weather API failed');
      const j = await res.json();
      const data = {
        temp: j.current?.temperature_2m,
        code: j.current?.weather_code,
        unit: 'C',
        place: null,
        ts: Date.now(),
      };
      // Try reverse geocoding (best effort)
      try {
        const g = await fetch(
          `https://geocoding-api.open-meteo.com/v1/reverse?latitude=${lat}&longitude=${lon}&count=1&language=en&format=json`
        );
        if (g.ok) {
          const gj = await g.json();
          const r = gj.results?.[0];
          if (r) data.place = [r.name, r.admin1].filter(Boolean).join(', ');
        }
      } catch {}
      save(K.weather, data);
      renderWeather(data);
    } catch (err) {
      descEl.textContent = err?.code === 1
        ? 'Location permission denied'
        : 'Could not load weather';
    }
  };

  const cachedWeather = load(K.weather, null);
  if (cachedWeather) renderWeather(cachedWeather);
  refreshBtn.addEventListener('click', fetchWeather);
  if (!cachedWeather || Date.now() - cachedWeather.ts > 30 * 60 * 1000) {
    // Auto-fetch on first load if no cache or stale > 30 min (best effort; permission may prompt)
    setTimeout(fetchWeather, 600);
  }

  // ---------- Stats ----------
  const defaultStats = [
    { label: 'Steps', value: '0' },
    { label: 'Water (cups)', value: '0' },
    { label: 'Focus (min)', value: '0' },
    { label: 'Sleep (h)', value: '0' },
  ];
  const statsGrid = document.getElementById('statsGrid');
  const editStatsBtn = document.getElementById('editStats');
  let stats = load(K.stats, defaultStats);
  let editingStats = false;

  const renderStats = () => {
    statsGrid.innerHTML = '';
    stats.forEach((s, i) => {
      const el = document.createElement('div');
      el.className = 'stat' + (editingStats ? ' editing' : '');
      el.innerHTML = `
        <div class="label" ${editingStats ? 'contenteditable="true"' : ''} data-k="label" data-i="${i}">${escapeHtml(s.label)}</div>
        <div class="value" ${editingStats ? 'contenteditable="true"' : ''} data-k="value" data-i="${i}">${escapeHtml(s.value)}</div>
      `;
      statsGrid.appendChild(el);
    });
  };
  statsGrid.addEventListener('input', (e) => {
    const t = e.target;
    if (!t.dataset || t.dataset.i == null) return;
    const i = +t.dataset.i;
    stats[i][t.dataset.k] = t.textContent.trim();
    save(K.stats, stats);
  });
  editStatsBtn.addEventListener('click', () => {
    editingStats = !editingStats;
    editStatsBtn.textContent = editingStats ? 'Done' : 'Edit';
    renderStats();
  });
  renderStats();

  // ---------- Todos ----------
  const todoForm = document.getElementById('todoForm');
  const todoInput = document.getElementById('todoInput');
  const todoList = document.getElementById('todoList');
  const todoCount = document.getElementById('todoCount');
  let todos = load(K.todos, []);

  const renderTodos = () => {
    todoList.innerHTML = '';
    if (todos.length === 0) {
      const empty = document.createElement('li');
      empty.className = 'empty';
      empty.textContent = 'No tasks yet. Add one above ↑';
      todoList.appendChild(empty);
    } else {
      todos.forEach((t) => {
        const li = document.createElement('li');
        li.className = 'todo-item' + (t.done ? ' done' : '');
        li.innerHTML = `
          <input class="check" type="checkbox" ${t.done ? 'checked' : ''} aria-label="Toggle task" />
          <span class="todo-text">${escapeHtml(t.text)}</span>
          <button class="delete-btn" aria-label="Delete task" title="Delete">×</button>
        `;
        li.querySelector('.check').addEventListener('change', (e) => {
          t.done = e.target.checked;
          save(K.todos, todos);
          li.classList.toggle('done', t.done);
          updateCount();
        });
        li.querySelector('.delete-btn').addEventListener('click', () => {
          todos = todos.filter((x) => x.id !== t.id);
          save(K.todos, todos);
          renderTodos();
        });
        todoList.appendChild(li);
      });
    }
    updateCount();
  };
  const updateCount = () => {
    const done = todos.filter((t) => t.done).length;
    todoCount.textContent = `${done} / ${todos.length}`;
  };
  todoForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const text = todoInput.value.trim();
    if (!text) return;
    todos.unshift({ id: uid(), text, done: false, created: Date.now() });
    save(K.todos, todos);
    todoInput.value = '';
    renderTodos();
  });
  renderTodos();

  // ---------- Habits (daily streaks) ----------
  const habitList = document.getElementById('habitList');
  const addHabitBtn = document.getElementById('addHabit');
  let habits = load(K.habits, [
    { id: uid(), name: 'Drink water', history: [] },
    { id: uid(), name: 'Move 30 min', history: [] },
  ]);

  const streakOf = (h) => {
    const set = new Set(h.history || []);
    let streak = 0;
    const d = new Date();
    // If today not yet done, streak counts from yesterday back
    if (!set.has(todayKey())) d.setDate(d.getDate() - 1);
    while (set.has(d.toISOString().slice(0, 10))) {
      streak++;
      d.setDate(d.getDate() - 1);
    }
    return streak;
  };

  const renderHabits = () => {
    habitList.innerHTML = '';
    if (habits.length === 0) {
      const empty = document.createElement('li');
      empty.className = 'empty';
      empty.textContent = 'No habits yet. Tap + Add to start tracking.';
      habitList.appendChild(empty);
      return;
    }
    const today = todayKey();
    habits.forEach((h) => {
      const done = (h.history || []).includes(today);
      const streak = streakOf(h);
      const li = document.createElement('li');
      li.className = 'habit-item' + (done ? ' done' : '');
      li.innerHTML = `
        <input class="check" type="checkbox" ${done ? 'checked' : ''} aria-label="Toggle habit" />
        <span class="habit-name">${escapeHtml(h.name)}</span>
        <span class="habit-streak" title="Current streak">🔥 ${streak}</span>
        <button class="delete-btn" aria-label="Delete habit" title="Delete">×</button>
      `;
      li.querySelector('.check').addEventListener('change', (e) => {
        h.history = h.history || [];
        if (e.target.checked) {
          if (!h.history.includes(today)) h.history.push(today);
        } else {
          h.history = h.history.filter((d) => d !== today);
        }
        save(K.habits, habits);
        renderHabits();
      });
      li.querySelector('.delete-btn').addEventListener('click', () => {
        if (confirm(`Delete habit "${h.name}"?`)) {
          habits = habits.filter((x) => x.id !== h.id);
          save(K.habits, habits);
          renderHabits();
        }
      });
      habitList.appendChild(li);
    });
  };
  addHabitBtn.addEventListener('click', () => {
    const name = prompt('New habit name:');
    if (!name) return;
    habits.push({ id: uid(), name: name.trim(), history: [] });
    save(K.habits, habits);
    renderHabits();
  });
  renderHabits();

  // ---------- Notes ----------
  const notesEl = document.getElementById('notes');
  const notesSaved = document.getElementById('notesSaved');
  notesEl.value = load(K.notes, '');
  let notesTimer;
  notesEl.addEventListener('input', () => {
    notesSaved.textContent = 'Saving…';
    clearTimeout(notesTimer);
    notesTimer = setTimeout(() => {
      save(K.notes, notesEl.value);
      notesSaved.textContent = 'Saved';
    }, 400);
  });

  // ---------- Utils ----------
  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    }[c]));
  }

  // ---------- Service worker ----------
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('sw.js').catch(() => {});
    });
  }
})();
