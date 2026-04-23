import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(TunnelManager.self) private var tunnel
    @Environment(Theme.self) private var theme
    @Query(sort: \TunnelRecord.createdAt, order: .reverse) private var tunnels: [TunnelRecord]

    var body: some View {
        ZStack {
            GradientBackground()
            ScrollView {
                VStack(spacing: 28) {
                    header
                    ringBlock
                    primaryActionButton
                    StatsPanel()
                        .card()
                    activeTunnelCard
                        .card()
                    ProvisioningReminderCard()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Ultron")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text(statusLine)
                    .font(.subheadline)
                    .foregroundStyle(theme.statusColor(tunnel.snapshot.status))
                    .contentTransition(.numericText())
            }
            Spacer()
            Image(systemName: "bolt.shield.fill")
                .font(.title2)
                .foregroundStyle(theme.accent)
        }
    }

    private var ringBlock: some View {
        ZStack {
            ConnectRingView(status: tunnel.snapshot.status, isBusy: tunnel.isBusy)
            VStack(spacing: 6) {
                Text(statusHeadline)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .contentTransition(.opacity)
                if let name = tunnel.snapshot.tunnelName {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var primaryActionButton: some View {
        Button {
            Task { await tunnel.toggle() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: buttonIcon)
                    .font(.headline)
                Text(buttonTitle)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [theme.accent, theme.accentGlow],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .opacity(tunnels.isEmpty ? 0.3 : 1.0)
            }
            .foregroundStyle(.black)
        }
        .disabled(tunnels.isEmpty || tunnel.isBusy)
        .sensoryFeedback(.impact(weight: .medium), trigger: tunnel.snapshot.status)
    }

    private var activeTunnelCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Active tunnel")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if tunnel.snapshot.status == .connected {
                    Circle().fill(theme.success).frame(width: 8, height: 8)
                    Text("Up")
                        .font(theme.monoCaption)
                        .foregroundStyle(theme.success)
                }
            }
            Text(tunnel.snapshot.tunnelName ?? "None")
                .font(.title3.weight(.semibold))
            if let hs = tunnel.snapshot.lastHandshake {
                Text("Last handshake \(hs, style: .relative) ago")
                    .font(theme.monoCaption)
                    .foregroundStyle(.secondary)
            } else if tunnels.isEmpty {
                Text("Import a WireGuard config to get started.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusLine: String {
        switch tunnel.snapshot.status {
        case .disconnected: return "Disconnected"
        case .handshaking:  return "Handshaking…"
        case .connected:    return "Protected"
        case .degraded:     return "Degraded link"
        case .failed:       return "Failed"
        }
    }

    private var statusHeadline: String {
        switch tunnel.snapshot.status {
        case .connected:    return "Protected"
        case .handshaking:  return "Connecting"
        case .degraded:     return "Degraded"
        case .failed:       return "Failed"
        case .disconnected: return tunnels.isEmpty ? "No tunnels" : "Tap to connect"
        }
    }

    private var buttonTitle: String {
        switch tunnel.snapshot.status {
        case .connected, .handshaking, .degraded: return "Disconnect"
        default: return "Connect"
        }
    }

    private var buttonIcon: String {
        switch tunnel.snapshot.status {
        case .connected, .handshaking, .degraded: return "stop.fill"
        default: return "play.fill"
        }
    }
}
