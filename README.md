# Ultron VPN

A personal WireGuard client for iOS 17+ with live stats, a Home Screen widget,
Control Center toggle, and a one-tap launcher into [Moonlight] for low-latency
PC streaming from your home rig over the tunnel.

Built for sideloading on a single iPhone — no App Store submission, no account,
no backend, no telemetry. WireGuard-only, so if you can load a config into
[`wg-quick`] or the official WireGuard client, Ultron will connect to the same
peer (including an existing Tailnet or self-hosted Headscale).

[Moonlight]: https://moonlight-stream.org
[`wg-quick`]: https://man.archlinux.org/man/community/wireguard-tools/wg-quick.8.en

---

## What you get

- **Tunnel**: WireGuard via Apple's `NEPacketTunnelProvider` + `WireGuardKit`.
- **Import**: QR scan, `.conf` file picker, clipboard paste, or manual form
  (Tailscale/Headscale-friendly).
- **Live stats**: up/down throughput, total bytes, handshake age, RTT.
- **Hero UI**: animated connect ring (TimelineView + Canvas) that shifts colour
  and pulse rate as the tunnel goes through handshaking → connected → degraded.
- **Per-peer cards** with live ping and a **Stream** button that deep-links
  into Moonlight with the host IP pre-filled.
- **On-Demand** rules (auto-connect on Wi-Fi / cellular).
- **Kill switch** (`includeAllNetworks`) and LAN-access toggle.
- **Split tunneling** via excluded routes / `AllowedIPs` override.
- **Widgets**: small + medium Home Screen widgets, plus an iOS 18 Control
  Center / Lock Screen toggle, all driven by the same App Intent that powers
  the Shortcuts action ("Toggle Ultron VPN").
- **Logs** export to the Files app.
- **Provisioning reminder** for the 7-day free sideload signing window.

---

## Requirements

- macOS with **Xcode 15.3+**
- An iPhone on **iOS 17** or later (iOS 18 for the Control Center widget)
- [**XcodeGen**](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- For the Network Extension entitlement to work reliably you'll want a **paid
  Apple Developer account** ($99/yr). A free Apple ID *can* grant the
  entitlement, but signatures expire every 7 days and free-tier VPN entitlements
  are occasionally flaky.

---

## Generate the Xcode project

This repo ships a declarative `project.yml`; XcodeGen turns it into a
`UltronVPN.xcodeproj` with all three targets wired up correctly.

```sh
brew install xcodegen
xcodegen generate
open UltronVPN.xcodeproj
```

You should see three targets:

| Target          | Kind           | Bundle ID                                        |
| --------------- | -------------- | ------------------------------------------------ |
| `UltronVPN`     | iOS app        | `com.davidwilliams.ultronvpn`                    |
| `PacketTunnel`  | app extension  | `com.davidwilliams.ultronvpn.tunnel`             |
| `UltronWidget`  | widget         | `com.davidwilliams.ultronvpn.widget`             |

All three share the App Group `group.com.davidwilliams.ultronvpn` and the
keychain access group `com.davidwilliams.ultronvpn`.

> **Rename the bundle prefix** (`com.davidwilliams.ultronvpn`) to something
> under your own team before signing. Update it in three places: `project.yml`,
> `SharedConstants.swift`, and every `*.entitlements`.

## Capabilities in Xcode

When you switch the team on the `UltronVPN` target, Xcode will regenerate the
provisioning profile. You need to manually add or re-check these capabilities
on the `UltronVPN` and `PacketTunnel` targets:

- **Network Extensions** → `Packet Tunnel` (required)
- **App Groups** → `group.com.davidwilliams.ultronvpn`
- **Keychain Sharing** → `com.davidwilliams.ultronvpn`
- **Personal VPN** — needed on the `UltronVPN` target so iOS will let
  `NETunnelProviderManager.saveToPreferences()` succeed.

On the `UltronWidget` target you only need **App Groups**.

---

## Importing a config

### From a QR code (what the official WireGuard clients print)

1. On your server, generate a peer config and print it with `qrencode`:
   ```sh
   qrencode -t ansiutf8 < iphone.conf
   ```
2. In Ultron: Tunnels → + → **Scan QR code**.

### From a `.conf` file

AirDrop or iCloud-copy the file onto the phone, then Tunnels → + → **Import
.conf file**.

### Paste

Tunnels → + → **Paste config**. Ultron pre-fills from the clipboard.

### Manual (Tailscale / Headscale)

If you're plugging into an existing Tailnet, use `tailscale up` on the server
to print the WireGuard keys, or [use Headscale's raw WireGuard endpoint]. Fill
in Ultron's **Manual entry** form with:

- Your node's private key + tailnet IP (e.g. `100.64.0.42/32`)
- MagicDNS / Headscale DNS (`100.100.100.100` for Tailscale)
- A coordination server's public key and endpoint, with
  `AllowedIPs = 100.64.0.0/10, fd7a:115c::/48`

[use Headscale's raw WireGuard endpoint]: https://github.com/juanfont/headscale/blob/main/docs/exit-node.md

---

## Pairing with Sunshine on your PC

1. Install [Sunshine](https://app.lizardbyte.dev/Sunshine) on your PC and
   start it. Note the **server IP** on the PC inside your tunnel (Tailscale
   100.x, or whatever AllowedIPs routes to your PC).
2. Install [Moonlight] from the App Store on your iPhone.
3. Open Moonlight once, add the PC manually with the tunnel IP, and pair
   using the 4-digit code on Sunshine's web UI (`https://<pc-ip>:47990`).
4. Open Ultron → Devices. Your PC peer will show up with a **Stream** button
   once it's reachable on port 47989.

> Ultron deep-links to Moonlight via `moonlight://<host>`. It doesn't
> reimplement streaming — Moonlight handles that part.

---

## Sideloading

### With a paid Apple Developer account (recommended)

In Xcode:

1. Signing & Capabilities → Team → *your team*.
2. `Product → Destination → <your iPhone>`.
3. `Product → Run`.

Signatures last ~1 year. You can also ship a `.ipa` via TestFlight if you
really want, but there's nothing here that's App-Store-review-friendly.

### With a free Apple ID (7-day signatures)

iOS revokes the provisioning profile every 7 days, which kills the Packet
Tunnel extension. Your options:

- **Xcode**: Plug in, `Product → Run` every time you notice the widget stuck
  on "Disconnected". Ultron's Home screen will nag you a couple of days before
  expiry.
- **[AltStore]** / **[AltStore PAL]**: refreshes automatically while your Mac
  is on the same Wi-Fi.
- **[Sideloadly]**: drag-and-drop an `.ipa`, re-sign when it expires.

After each resign, open Settings in Ultron and tap **Mark resigned now** so
the countdown card resets.

[AltStore]: https://altstore.io
[AltStore PAL]: https://altstore.io/pal
[Sideloadly]: https://sideloadly.io

> **About free-tier VPN entitlements**: Apple *does* allow
> `packet-tunnel-provider` with free provisioning, but it's been known to be
> refused with opaque errors. If you see "Could not start tunnel: permission
> denied" after a resign, regenerate the profile (delete the app, reinstall)
> or fall back to a paid account.

---

## Architecture

```
UltronVPN (app)        SwiftUI + @Observable + SwiftData
├─ Features/           Home, Devices, Tunnels, Settings
├─ Core/
│  ├─ Tunnel/          NETunnelProviderManager wrapper, stats pump
│  ├─ WireGuard/       Parser for wg-quick .conf files
│  ├─ Networking/      TCP-based peer ping
│  ├─ Persistence/     SwiftData models (TunnelRecord, PeerRecord)
│  └─ Haptics/         CHHapticEngine wrapper
└─ Theme/              Deep-teal accent, gradient backgrounds, card style

Shared/                Code used by app + extension + widget
├─ KeychainService     Access-group-aware private key storage
├─ WireGuardConfig     Codable, moves across XPC boundary
├─ TunnelProviderPayload  App → extension hand-off
├─ TunnelStats         Extension → app stats reply
├─ TunnelStatusSnapshot   Anything writes it; widget reads it
├─ ToggleTunnelIntent  App Intent used by widget + Control Center + Shortcuts
└─ Log                 App-Group-backed ring buffer

PacketTunnel/          NEPacketTunnelProvider subclass + WireGuardKit adapter

UltronWidget/          StatusWidget (home screen) + StatusControlWidget (iOS 18)
```

### Secrets

Private keys and preshared keys never touch SwiftData or `UserDefaults`. The
import flow writes them to the Keychain under the shared access group; the
extension reads them back by a per-tunnel opaque tag.

### IPC

App → extension:

```swift
session.sendProviderMessage(TunnelProviderMessage.stats.encoded) { reply in
    let stats = try? JSONDecoder().decode(TunnelStats.self, from: reply)
}
```

The extension picks up stats by parsing WireGuardKit's `getRuntimeConfiguration`
output (`rx_bytes=…`, `last_handshake_time_sec=…`).

---

## Non-goals

- No App Store submission. No privacy manifest, no localization beyond English.
- No custom protocol. WireGuard only.
- No Android, no macOS Catalyst.
- No telemetry, no ads, no analytics, no account.
- Don't reimplement Moonlight's streaming stack — deep-link only.

---

## Licensing

WireGuard is © Jason A. Donenfeld and the WireGuard contributors; this project
links against [wireguard-apple] under its MIT license.

[wireguard-apple]: https://git.zx2c4.com/wireguard-apple
