import SwiftUI
import UIKit

struct DeviceCard: View {
    @Environment(Theme.self) private var theme
    let peer: PeerRecord
    let latencyMs: Int?
    let tunnelConnected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: peer.osGlyph)
                    .font(.title2)
                    .foregroundStyle(theme.accent)
                    .frame(width: 36, height: 36)
                    .background(theme.accentSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(peer.displayName)
                        .font(.body.weight(.semibold))
                    if let ip = peer.reachableIP {
                        Text(ip)
                            .font(theme.monoCaption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                latencyBadge
            }

            if peer.isStreamHost {
                Button(action: launchMoonlight) {
                    HStack(spacing: 8) {
                        Image(systemName: "gamecontroller.fill")
                        Text("Stream")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(theme.accent, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.black)
                }
                .disabled(!tunnelConnected || peer.reachableIP == nil)
                .opacity((tunnelConnected && peer.reachableIP != nil) ? 1 : 0.4)
            }
        }
        .card()
    }

    private var latencyBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(latencyColor)
                .frame(width: 8, height: 8)
            Text(latencyText)
                .font(theme.monoCaption)
                .foregroundStyle(.secondary)
        }
    }

    private var latencyText: String {
        guard tunnelConnected else { return "offline" }
        guard let ms = latencyMs else { return "…" }
        return "\(ms) ms"
    }

    private var latencyColor: Color {
        guard tunnelConnected, let ms = latencyMs else { return .gray }
        switch ms {
        case ..<40: return theme.success
        case ..<120: return theme.warning
        default: return theme.danger
        }
    }

    private func launchMoonlight() {
        guard let ip = peer.reachableIP else { return }
        // Moonlight's URL scheme: moonlight://<host>  (some builds use moonlight://hostname?ip=...)
        // Prefer the simple form and fall back if it can't be opened.
        let primary = URL(string: "moonlight://\(ip)")!
        let fallback = URL(string: "moonlight://hostname?ip=\(ip)")!
        UIApplication.shared.open(primary) { ok in
            if !ok { UIApplication.shared.open(fallback) }
        }
    }
}
