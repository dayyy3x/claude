import WidgetKit
import SwiftUI
import AppIntents

struct StatusTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatusEntry {
        StatusEntry(date: .now, snapshot: .disconnected)
    }

    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        completion(StatusEntry(date: .now, snapshot: TunnelStatusStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        // Refresh every 60 seconds; NE notifications can also kick a reload.
        let entries = (0..<5).map { i in
            StatusEntry(date: Date().addingTimeInterval(Double(i) * 60), snapshot: TunnelStatusStore.read())
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct StatusEntry: TimelineEntry {
    let date: Date
    let snapshot: TunnelStatusSnapshot
}

struct StatusWidget: Widget {
    let kind = "UltronStatus"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatusTimelineProvider()) { entry in
            StatusWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Ultron")
        .description("Tunnel status and one-tap toggle.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct StatusWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: StatusEntry

    var body: some View {
        switch family {
        case .systemMedium: medium
        default:            small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(statusColor).frame(width: 10, height: 10)
                Text(statusText).font(.caption.weight(.semibold))
            }
            Text(entry.snapshot.tunnelName ?? "No tunnel")
                .font(.headline)
                .lineLimit(1)
            Spacer()
            Button(intent: ToggleTunnelIntent()) {
                Label(toggleLabel, systemImage: toggleIcon)
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
        }
    }

    private var medium: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(statusColor.opacity(0.3), lineWidth: 4)
                Circle().trim(from: 0, to: progress)
                    .stroke(statusColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(statusColor)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.snapshot.tunnelName ?? "Ultron")
                    .font(.headline)
                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if entry.snapshot.bytesReceived + entry.snapshot.bytesSent > 0 {
                    Text(byteLine)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(intent: ToggleTunnelIntent()) {
                Image(systemName: toggleIcon)
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
        }
    }

    private var accent: Color { Color(red: 0.09, green: 0.72, blue: 0.74) }

    private var statusText: String {
        switch entry.snapshot.status {
        case .connected: return "Protected"
        case .handshaking: return "Handshaking…"
        case .degraded: return "Degraded"
        case .failed: return "Failed"
        case .disconnected: return "Disconnected"
        }
    }

    private var statusColor: Color {
        switch entry.snapshot.status {
        case .connected: return accent
        case .handshaking: return .yellow
        case .degraded: return .orange
        case .failed: return .red
        case .disconnected: return .gray
        }
    }

    private var progress: CGFloat {
        switch entry.snapshot.status {
        case .connected: return 1
        case .handshaking, .degraded: return 0.6
        default: return 0.1
        }
    }

    private var toggleLabel: String {
        entry.snapshot.status == .connected ? "Disconnect" : "Connect"
    }

    private var toggleIcon: String {
        entry.snapshot.status == .connected ? "stop.fill" : "play.fill"
    }

    private var byteLine: String {
        let f = ByteCountFormatter(); f.countStyle = .binary
        let rx = f.string(fromByteCount: Int64(entry.snapshot.bytesReceived))
        let tx = f.string(fromByteCount: Int64(entry.snapshot.bytesSent))
        return "↓ \(rx)  ↑ \(tx)"
    }
}
