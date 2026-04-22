# Remote

A mobile launcher for your Tailscale devices. One tap to SSH or RDP into a machine, installable to your phone's home screen as a PWA.

## What it does

- **Device list** you manage on your phone — add any Tailscale hostname.
- **One-tap launch:**
  - **SSH** — opens `ssh://user@host:port` (handled by Termius or Blink Shell on iOS, Termius on Android).
  - **RDP** — opens an `rdp://` URL that the Microsoft Remote Desktop app consumes directly.
  - **Copy** — copies the equivalent `ssh` one-liner to the clipboard as a fallback.
  - **Web** — opens `http://host:port` in the browser (Plex, Home Assistant, NAS, whatever).
- **Saved commands** per device — label + command body, tap to copy.
- **Works offline**, installable as a PWA, **100% local** (all data in `localStorage`).

## Prereqs

1. **Tailscale** installed and signed in on your phone and each device you want to reach.
2. On each target device, the matching service running:
   - SSH → OpenSSH Server (Linux has it; on Windows install via `Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0`).
   - RDP → Windows Pro/Enterprise/Education with Remote Desktop enabled (Settings → System → Remote Desktop).
3. On the phone, install the launching apps:
   - SSH: [**Termius**](https://apps.apple.com/app/termius/id549039908) (free) or [**Blink Shell**](https://apps.apple.com/app/blink-shell-code-editor/id1594898306) (paid, excellent).
   - RDP: [**Microsoft Remote Desktop**](https://apps.apple.com/app/microsoft-remote-desktop/id714464092) (free, official).

## Get it on your phone

Serve the files over HTTPS so the service worker and "Add to Home Screen" work.

### GitHub Pages (recommended)

1. Push this branch.
2. Repo → Settings → Pages → set **Source** to this branch, root `/`.
3. Open the resulting `https://<you>.github.io/<repo>/` URL on your phone.
4. iPhone Safari: Share → *Add to Home Screen*. Android Chrome: ⋮ → *Install app*.

### Local over Wi-Fi

```sh
python3 -m http.server 8000
```

Find your computer's LAN IP and on your phone open `http://192.168.x.y:8000`. For PWA install over HTTPS: `npx --yes localtunnel --port 8000`.

## How the launch URLs work

- **SSH** → `ssh://user@hostname:port` — iOS and Android SSH clients register this scheme.
- **RDP** → `rdp://full%20address=s:host:3389&username=s:user` — Microsoft Remote Desktop accepts the same key/value pairs as an `.rdp` file, URL-encoded.
- **Web** → regular `http://host:port/`.
- **Copy** → writes `ssh [user@]host [-p port]` to the clipboard via the Clipboard API (fallback: hidden textarea + `execCommand('copy')`).

If no compatible app is installed, the OS leaves the browser open and the app shows a toast telling you which app to install.

## File layout

```
index.html              app shell (device list + device detail)
styles.css              styles (dark + light)
app.js                  all logic (devices, launchers, commands)
manifest.webmanifest    PWA manifest
sw.js                   service worker (offline cache)
icons/                  home-screen icons
```

## Privacy

No network calls. No accounts. No telemetry. Every device and saved command stays in your browser's `localStorage`.
