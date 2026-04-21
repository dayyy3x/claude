# Grades

A mobile grade tracker you can install on your phone's home screen. Built for finals week: add your classes, punch in assignments, and see exactly what you need on the final to hit your target grade.

## What it does

- **Per-class grades** — add assignments with earned / total points, optional weight %.
- **Live weighted average** — shows your current grade + letter, updates as you type.
- **Final exam calculator** — "you need **87.3%** on the final to get **90%** in this class."
- **Overall GPA (4.0 scale)** on the home screen across all classes.
- **Works offline** (service worker cache), installs as a PWA.
- **100% local** — all data stays in `localStorage` on your device. No account.

## Get it on your phone

You need to serve the files over HTTPS (or `http://localhost`) for the service worker and "add to home screen" to work. Two easy options:

### Option A — GitHub Pages (recommended, free)

1. Push this repo to GitHub.
2. In the repo, go to **Settings → Pages**, set **Source** to this branch and the root `/` folder.
3. Wait ~1 minute. GitHub will give you a URL like `https://<you>.github.io/<repo>/`.
4. Open that URL on your phone.
5. Add to home screen:
   - **iPhone (Safari):** Share → *Add to Home Screen*.
   - **Android (Chrome):** ⋮ menu → *Install app* / *Add to Home screen*.

### Option B — Serve locally on your Wi-Fi

From this directory:

```sh
python3 -m http.server 8000
# or
npx --yes serve -l 8000 .
```

Find your computer's LAN IP (e.g. `192.168.1.42`) and on your phone open `http://192.168.1.42:8000`. For an HTTPS tunnel so PWA install works, try `npx --yes localtunnel --port 8000`.

## How the grade math works

Each assignment has **earned / total** points and an optional **weight %**.

- If you set a **weight** on any assignment, the class grade is a **weighted average**: `sum(pct × weight) / sum(weight)`. Typical setup: Homework 20%, Quizzes 20%, Midterm 20%, Final 40% — add each as a single "assignment" with that weight, or add individual items whose weights sum to the category total.
- If **no assignment has a weight**, the class grade is **point-based**: `sum(earned) / sum(total) × 100`.
- The **final exam calculator** assumes the final is separate. It uses your current non-final grade and the final's weight to compute what you need on the final to hit your target:
  - `needed_on_final = (target − current × (1 − finalWeight)) / finalWeight`
  - So the assignments you enter should be **everything except the final** — don't add the final itself as an assignment.

Tip: the "Weights: X% of Y%" indicator shows how much of the non-final grade you've assigned, so you know whether your weights are set up correctly.

## File layout

```
index.html              app shell (home + course detail)
styles.css              styles (dark + light)
app.js                  all logic (courses, grades, final calc)
manifest.webmanifest    PWA manifest
sw.js                   service worker (offline cache)
icons/                  home-screen icons
```

## Customising

- **Add a class:** type its name in the box on the home screen, hit +.
- **Edit a class:** tap it. Rename by typing in the name field. Set final weight and target grade at the top of the card.
- **Add assignments:** name, earned, total, and optional weight %. Tap × to delete.
- **Theme:** moon icon, top right.
- **Reset:** clear site data in your browser settings (wipes all local data).

## Privacy

Nothing leaves your device. There is no backend, no analytics, no network calls.
