/* Mobile grade tracker — vanilla JS, saves to localStorage. */
(() => {
  'use strict';

  // ---------- Storage ----------
  const K = { courses: 'gt_courses', theme: 'gt_theme', lastCourse: 'gt_last' };
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

  // ---------- Data model ----------
  // Course: { id, name, finalWeight (0-100), targetGrade (0-100), assignments: [
  //   { id, name, earned, total, weight (0-100, optional) }
  // ] }
  let courses = load(K.courses, []);
  if (!Array.isArray(courses)) courses = [];

  const persist = () => save(K.courses, courses);

  // Grade math. Returns { pct, weightUsed } or null if nothing graded yet.
  // If any assignment has a user-set weight, we use weighted mode: sum(pct*w)/sum(w).
  // Otherwise points mode: sum(earned)/sum(total)*100.
  const computeCurrentGrade = (course) => {
    const as = (course.assignments || []).filter(a =>
      isFinite(+a.earned) && isFinite(+a.total) && +a.total > 0
    );
    if (!as.length) return null;
    const anyWeighted = as.some(a => a.weight !== '' && a.weight != null && isFinite(+a.weight) && +a.weight > 0);
    if (anyWeighted) {
      let sumWP = 0, sumW = 0;
      for (const a of as) {
        const w = (a.weight !== '' && a.weight != null && isFinite(+a.weight)) ? +a.weight : 0;
        if (w <= 0) continue;
        const pct = (+a.earned / +a.total) * 100;
        sumWP += pct * w; sumW += w;
      }
      if (sumW <= 0) return null;
      return { pct: sumWP / sumW, weightUsed: sumW };
    } else {
      let e = 0, t = 0;
      for (const a of as) { e += +a.earned; t += +a.total; }
      if (t <= 0) return null;
      return { pct: (e / t) * 100, weightUsed: null };
    }
  };

  const letterOf = (pct) => {
    if (pct == null || !isFinite(pct)) return '';
    if (pct >= 93) return 'A';
    if (pct >= 90) return 'A-';
    if (pct >= 87) return 'B+';
    if (pct >= 83) return 'B';
    if (pct >= 80) return 'B-';
    if (pct >= 77) return 'C+';
    if (pct >= 73) return 'C';
    if (pct >= 70) return 'C-';
    if (pct >= 67) return 'D+';
    if (pct >= 63) return 'D';
    if (pct >= 60) return 'D-';
    return 'F';
  };

  // Standard US 4.0 unweighted scale
  const gpaOf = (pct) => {
    if (pct == null || !isFinite(pct)) return null;
    if (pct >= 93) return 4.0;
    if (pct >= 90) return 3.7;
    if (pct >= 87) return 3.3;
    if (pct >= 83) return 3.0;
    if (pct >= 80) return 2.7;
    if (pct >= 77) return 2.3;
    if (pct >= 73) return 2.0;
    if (pct >= 70) return 1.7;
    if (pct >= 67) return 1.3;
    if (pct >= 63) return 1.0;
    if (pct >= 60) return 0.7;
    return 0.0;
  };

  const fmtPct = (n) => (n == null || !isFinite(n)) ? '—' : `${n.toFixed(1)}%`;

  // ---------- Views ----------
  const homeView = document.getElementById('homeView');
  const courseView = document.getElementById('courseView');
  const backBtn = document.getElementById('backBtn');
  const appTitle = document.getElementById('appTitle');
  const appSubtitle = document.getElementById('appSubtitle');

  let currentCourseId = null;

  const showHome = () => {
    currentCourseId = null;
    save(K.lastCourse, null);
    homeView.classList.remove('hidden');
    courseView.classList.add('hidden');
    backBtn.classList.add('hidden');
    appTitle.textContent = 'Grades';
    appSubtitle.textContent = courses.length
      ? 'Tap a class to edit · finals ready'
      : 'Add your classes to get started';
    renderHome();
  };

  const showCourse = (id) => {
    const c = courses.find(x => x.id === id);
    if (!c) return showHome();
    currentCourseId = id;
    save(K.lastCourse, id);
    homeView.classList.add('hidden');
    courseView.classList.remove('hidden');
    backBtn.classList.remove('hidden');
    appTitle.textContent = c.name || 'Class';
    appSubtitle.textContent = 'Add assignments and see your grade live';
    renderCourse();
  };

  backBtn.addEventListener('click', showHome);

  // ---------- Home render ----------
  const courseListEl = document.getElementById('courseList');
  const overallAvgEl = document.getElementById('overallAvg');
  const overallGpaEl = document.getElementById('overallGpa');
  const courseCountEl = document.getElementById('courseCount');
  const addCourseForm = document.getElementById('addCourseForm');
  const addCourseInput = document.getElementById('addCourseInput');

  const renderHome = () => {
    courseListEl.innerHTML = '';
    courseCountEl.textContent = String(courses.length);

    let gpaSum = 0, gpaN = 0, pctSum = 0, pctN = 0;

    if (!courses.length) {
      const empty = document.createElement('li');
      empty.className = 'empty-card card';
      empty.innerHTML = `
        <div class="empty-title">No classes yet</div>
        <div class="muted small">Add your first class below — we'll track assignments and tell you exactly what you need on the final.</div>
      `;
      courseListEl.appendChild(empty);
    } else {
      courses.forEach(c => {
        const res = computeCurrentGrade(c);
        const pct = res ? res.pct : null;
        const letter = letterOf(pct);
        const g = gpaOf(pct);
        if (pct != null) { pctSum += pct; pctN++; }
        if (g != null) { gpaSum += g; gpaN++; }

        const needed = computeNeededFinal(c, pct);

        const li = document.createElement('li');
        li.className = 'course-card card';
        li.innerHTML = `
          <div class="course-main">
            <div class="course-name">${escapeHtml(c.name || 'Untitled class')}</div>
            <div class="course-meta muted small">
              ${(c.assignments || []).length} assignment${(c.assignments || []).length === 1 ? '' : 's'}
              ${c.finalWeight ? ` · final ${c.finalWeight}%` : ''}
            </div>
          </div>
          <div class="course-side">
            <div class="course-pct">${fmtPct(pct)}</div>
            <div class="letter-pill ${letterClass(letter)}">${letter || '—'}</div>
          </div>
          ${needed != null ? `<div class="course-needed">
            Need <strong>${needed.toFixed(1)}%</strong> on final for ${c.targetGrade}%
          </div>` : ''}
        `;
        li.addEventListener('click', () => showCourse(c.id));
        courseListEl.appendChild(li);
      });
    }

    overallAvgEl.textContent = pctN ? `${(pctSum / pctN).toFixed(1)}%` : '—';
    overallGpaEl.textContent = gpaN ? (gpaSum / gpaN).toFixed(2) : '—';
  };

  addCourseForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const name = addCourseInput.value.trim();
    if (!name) return;
    const c = {
      id: uid(),
      name,
      finalWeight: 20,
      targetGrade: 90,
      assignments: [],
    };
    courses.push(c);
    persist();
    addCourseInput.value = '';
    showCourse(c.id);
  });

  // ---------- Course render ----------
  const courseNameInput = document.getElementById('courseName');
  const currentGradeEl = document.getElementById('currentGrade');
  const currentLetterEl = document.getElementById('currentLetter');
  const deleteCourseBtn = document.getElementById('deleteCourseBtn');
  const finalWeightInput = document.getElementById('finalWeight');
  const targetGradeInput = document.getElementById('targetGrade');
  const finalResultEl = document.getElementById('finalResult');
  const assignmentListEl = document.getElementById('assignmentList');
  const weightSumEl = document.getElementById('weightSum');
  const addAssignmentForm = document.getElementById('addAssignmentForm');

  const current = () => courses.find(c => c.id === currentCourseId);

  // Given current non-final grade (0-100) and a course, what % do they need on the final?
  // Formula: target = current*(1 - fw/100) + final*(fw/100)  =>
  //          final = (target - current*(1 - fw/100)) / (fw/100)
  const computeNeededFinal = (course, currentPct) => {
    const fw = +course.finalWeight;
    const target = +course.targetGrade;
    if (!isFinite(fw) || fw <= 0 || fw > 100) return null;
    if (!isFinite(target)) return null;
    if (currentPct == null || !isFinite(currentPct)) return null;
    const frac = fw / 100;
    return (target - currentPct * (1 - frac)) / frac;
  };

  const renderCourse = () => {
    const c = current();
    if (!c) return showHome();

    courseNameInput.value = c.name || '';
    finalWeightInput.value = c.finalWeight ?? '';
    targetGradeInput.value = c.targetGrade ?? '';

    const res = computeCurrentGrade(c);
    const pct = res ? res.pct : null;
    currentGradeEl.textContent = fmtPct(pct);
    const letter = letterOf(pct);
    currentLetterEl.textContent = letter;
    currentLetterEl.className = `letter-pill ${letterClass(letter)}`;

    // Weights sum
    const as = c.assignments || [];
    const wSum = as.reduce((s, a) => {
      const w = (a.weight !== '' && a.weight != null && isFinite(+a.weight)) ? +a.weight : 0;
      return s + w;
    }, 0);
    const fw = isFinite(+c.finalWeight) ? +c.finalWeight : 0;
    const nonFinalBudget = Math.max(0, 100 - fw);
    weightSumEl.textContent = wSum > 0
      ? `Weights: ${wSum}% of ${nonFinalBudget}%`
      : `Weights: points-based`;
    weightSumEl.classList.toggle('warn', wSum > nonFinalBudget + 0.01);

    // Final exam calculator output
    renderFinalResult(c, pct);

    // Assignments list
    assignmentListEl.innerHTML = '';
    if (!as.length) {
      const li = document.createElement('li');
      li.className = 'empty';
      li.textContent = 'No assignments yet. Add one below ↓';
      assignmentListEl.appendChild(li);
    } else {
      as.forEach((a) => {
        const pctA = (isFinite(+a.earned) && isFinite(+a.total) && +a.total > 0)
          ? (+a.earned / +a.total) * 100 : null;
        const li = document.createElement('li');
        li.className = 'assignment-item';
        li.innerHTML = `
          <div class="a-row">
            <input class="a-name" type="text" data-k="name" value="${escapeAttr(a.name || '')}" placeholder="Name" />
            <button class="delete-btn" aria-label="Delete">×</button>
          </div>
          <div class="a-row a-row-2">
            <input class="a-num" type="number" inputmode="decimal" step="0.01" data-k="earned" value="${a.earned ?? ''}" placeholder="Earned" />
            <span class="slash">/</span>
            <input class="a-num" type="number" inputmode="decimal" step="0.01" data-k="total" value="${a.total ?? ''}" placeholder="Total" />
            <input class="a-num" type="number" inputmode="decimal" step="0.1" min="0" max="100" data-k="weight" value="${a.weight ?? ''}" placeholder="Wt %" />
            <span class="a-pct">${pctA == null ? '—' : pctA.toFixed(1) + '%'}</span>
          </div>
        `;
        // Wire up inputs
        li.querySelectorAll('input[data-k]').forEach(inp => {
          inp.addEventListener('input', () => {
            const k = inp.dataset.k;
            let v = inp.value;
            if (k !== 'name') v = v === '' ? '' : +v;
            a[k] = v;
            persist();
            renderCourseLite();
          });
        });
        li.querySelector('.delete-btn').addEventListener('click', () => {
          c.assignments = c.assignments.filter(x => x.id !== a.id);
          persist();
          renderCourse();
        });
        assignmentListEl.appendChild(li);
      });
    }
  };

  // Lighter rerender that doesn't blow away focused inputs in the assignments list.
  const renderCourseLite = () => {
    const c = current();
    if (!c) return;
    const res = computeCurrentGrade(c);
    const pct = res ? res.pct : null;
    currentGradeEl.textContent = fmtPct(pct);
    const letter = letterOf(pct);
    currentLetterEl.textContent = letter;
    currentLetterEl.className = `letter-pill ${letterClass(letter)}`;

    // Update per-row pct labels
    const items = assignmentListEl.querySelectorAll('.assignment-item');
    (c.assignments || []).forEach((a, i) => {
      const el = items[i]?.querySelector('.a-pct');
      if (!el) return;
      const pctA = (isFinite(+a.earned) && isFinite(+a.total) && +a.total > 0)
        ? (+a.earned / +a.total) * 100 : null;
      el.textContent = pctA == null ? '—' : pctA.toFixed(1) + '%';
    });

    const wSum = (c.assignments || []).reduce((s, a) => {
      const w = (a.weight !== '' && a.weight != null && isFinite(+a.weight)) ? +a.weight : 0;
      return s + w;
    }, 0);
    const fw = isFinite(+c.finalWeight) ? +c.finalWeight : 0;
    const nonFinalBudget = Math.max(0, 100 - fw);
    weightSumEl.textContent = wSum > 0
      ? `Weights: ${wSum}% of ${nonFinalBudget}%`
      : `Weights: points-based`;
    weightSumEl.classList.toggle('warn', wSum > nonFinalBudget + 0.01);

    renderFinalResult(c, pct);
  };

  const renderFinalResult = (c, pct) => {
    const fw = +c.finalWeight;
    if (!isFinite(fw) || fw <= 0) {
      finalResultEl.textContent = 'Set a final weight above 0% to see what you need.';
      finalResultEl.className = 'final-result';
      return;
    }
    if (pct == null) {
      finalResultEl.textContent = 'Add a graded assignment to get a final-exam estimate.';
      finalResultEl.className = 'final-result';
      return;
    }
    const needed = computeNeededFinal(c, pct);
    if (needed == null) {
      finalResultEl.textContent = 'Need a target grade to compute.';
      finalResultEl.className = 'final-result';
      return;
    }

    const target = +c.targetGrade;
    let tone = '';
    let msg = '';
    if (needed > 100) {
      tone = 'bad';
      const maxPossible = pct * (1 - fw / 100) + 100 * (fw / 100);
      msg = `Need <strong>${needed.toFixed(1)}%</strong> on the final to hit ${target}% — not mathematically possible. Best case with 100% on final: <strong>${maxPossible.toFixed(1)}%</strong>.`;
    } else if (needed <= 0) {
      tone = 'good';
      msg = `You're already above ${target}%. A <strong>0%</strong> on the final still lands you at <strong>${(pct * (1 - fw / 100)).toFixed(1)}%</strong>.`;
    } else {
      tone = needed >= 90 ? 'warn' : needed >= 70 ? 'ok' : 'good';
      msg = `Need <strong>${needed.toFixed(1)}%</strong> on the final to get <strong>${target}%</strong> in the class.`;
    }
    finalResultEl.className = `final-result ${tone}`;
    finalResultEl.innerHTML = msg;
  };

  courseNameInput.addEventListener('input', () => {
    const c = current(); if (!c) return;
    c.name = courseNameInput.value;
    persist();
    appTitle.textContent = c.name || 'Class';
  });
  finalWeightInput.addEventListener('input', () => {
    const c = current(); if (!c) return;
    c.finalWeight = finalWeightInput.value === '' ? '' : +finalWeightInput.value;
    persist();
    renderCourseLite();
  });
  targetGradeInput.addEventListener('input', () => {
    const c = current(); if (!c) return;
    c.targetGrade = targetGradeInput.value === '' ? '' : +targetGradeInput.value;
    persist();
    renderCourseLite();
  });

  deleteCourseBtn.addEventListener('click', () => {
    const c = current(); if (!c) return;
    const ok = confirm(`Delete "${c.name || 'this class'}" and all its assignments?`);
    if (!ok) return;
    courses = courses.filter(x => x.id !== c.id);
    persist();
    showHome();
  });

  addAssignmentForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const c = current(); if (!c) return;
    const name = document.getElementById('aName').value.trim();
    const earned = document.getElementById('aEarned').value;
    const total = document.getElementById('aTotal').value;
    const weight = document.getElementById('aWeight').value;
    if (!name && earned === '' && total === '') return;
    c.assignments = c.assignments || [];
    c.assignments.push({
      id: uid(),
      name: name || 'Assignment',
      earned: earned === '' ? '' : +earned,
      total: total === '' ? '' : +total,
      weight: weight === '' ? '' : +weight,
    });
    persist();
    addAssignmentForm.reset();
    renderCourse();
  });

  // ---------- Utils ----------
  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, c => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    }[c]));
  }
  function escapeAttr(s) { return escapeHtml(s); }
  function letterClass(letter) {
    if (!letter) return '';
    const first = letter[0];
    return `l-${first.toLowerCase()}`;
  }

  // ---------- Boot ----------
  const lastId = load(K.lastCourse, null);
  if (lastId && courses.some(c => c.id === lastId)) {
    showCourse(lastId);
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
