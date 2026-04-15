# Dashboard

A mobile-first personal dashboard that runs in your phone's browser and installs to the home screen as a PWA.

Widgets:

- Live clock, date, and time-of-day greeting
- Weather (Open-Meteo, no API key required, uses geolocation)
- Editable stat cards
- Today's tasks (add, check off, delete)
- Habit tracker with daily streaks
- Quick notes (auto-saved)
- Dark / light theme toggle
- Works offline (service worker cache)
- All data saved locally on your device (localStorage)

## Get it on your phone

You need to serve the files over HTTPS (or `http://localhost`) for the service worker and geolocation to work. Two easy options:

### Option A — GitHub Pages (recommended, free)

1. Push this repo to GitHub.
2. In the repo, go to **Settings → Pages**, set **Source** to the branch that contains these files (e.g. `claude/mobile-dashboard-app-TiMuS`) and the root `/` folder.
3. Wait ~1 minute. GitHub will give you a URL like `https://<you>.github.io/<repo>/`.
4. Open that URL on your phone.
5. Add to home screen:
   - **iPhone (Safari):** Share → *Add to Home Screen*.
   - **Android (Chrome):** ⋮ menu → *Install app* / *Add to Home screen*.

### Option B — Serve locally on your Wi-Fi

From this directory, run any of:

```sh
python3 -m http.server 8000
# or
npx --yes serve -l 8000 .
```

Find your computer's LAN IP (e.g. `192.168.1.42`) and on your phone open `http://192.168.1.42:8000`.

Note: some PWA features (install, offline, geolocation) only activate over HTTPS or localhost. LAN HTTP works for browsing but install/weather may be limited. For a quick HTTPS tunnel, use `npx --yes localtunnel --port 8000` or similar.

## File layout

```
index.html              app shell
styles.css              styles (dark + light theme)
app.js                  all widget logic
manifest.webmanifest    PWA manifest
sw.js                   service worker (offline cache)
icons/
  icon.svg              vector icon
  icon-192.png          home-screen icon
  icon-512.png          splash / high-res icon
```

## Customising

- **Name / greeting:** tap your name at the top and type.
- **Stats:** tap **Edit** on the Stats card; the labels and values become editable.
- **Habits:** tap **+ Add** to create habits; tap the × to remove.
- **Theme:** tap the moon icon top-right.

All changes persist in `localStorage` on the device that made them (not synced between devices).

## Privacy

- Weather requests go directly from your browser to `api.open-meteo.com` (temperature + weather code) and `geocoding-api.open-meteo.com` (city name). No account needed.
- Nothing else leaves your device.
