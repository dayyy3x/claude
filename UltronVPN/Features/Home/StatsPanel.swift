import SwiftUI

struct StatsPanel: View {
    @Environment(TunnelManager.self) private var tunnel
    @Environment(Theme.self) private var theme

    var body: some View {
        HStack(spacing: 14) {
            metric("Down", value: format(tunnel.stats.throughputRxBps) + "/s", icon: "arrow.down")
            Divider().frame(height: 44).background(theme.stroke)
            metric("Up", value: format(tunnel.stats.throughputTxBps) + "/s", icon: "arrow.up")
            Divider().frame(height: 44).background(theme.stroke)
            metric("RTT", value: tunnel.stats.rttMs.map { "\($0) ms" } ?? "—", icon: "timer")
            Divider().frame(height: 44).background(theme.stroke)
            metric("Total", value: totalBytes(), icon: "sum")
        }
    }

    private func metric(_ label: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(theme.monoDigits)
                .contentTransition(.numericText())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
    }

    private func format(_ bps: UInt64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .binary
        f.allowedUnits = [.useKB, .useMB, .useGB]
        return f.string(fromByteCount: Int64(bps))
    }

    private func totalBytes() -> String {
        let f = ByteCountFormatter()
        f.countStyle = .binary
        return f.string(fromByteCount: Int64(tunnel.stats.bytesReceived + tunnel.stats.bytesSent))
    }
}
