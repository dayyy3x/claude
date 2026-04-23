import SwiftUI
import SwiftData

struct DevicesView: View {
    @Environment(Theme.self) private var theme
    @Environment(TunnelManager.self) private var tunnel
    @Query(sort: \PeerRecord.displayName) private var peers: [PeerRecord]
    @State private var latencies: [UUID: Int?] = [:]
    @State private var refreshTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack {
                GradientBackground(intensity: 0.35)
                content
            }
            .navigationTitle("Devices")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { probe() } label: { Image(systemName: "arrow.clockwise") }
                }
            }
            .task { startAutoRefresh() }
            .onDisappear { refreshTask?.cancel() }
        }
    }

    @ViewBuilder private var content: some View {
        if peers.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "display.2")
                    .font(.system(size: 44))
                    .foregroundStyle(theme.accent.opacity(0.7))
                Text("No peers yet")
                    .font(.title3.weight(.semibold))
                Text("Peers from your imported tunnels show up here with live ping.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(peers) { peer in
                        DeviceCard(peer: peer,
                                   latencyMs: latencies[peer.id] ?? nil,
                                   tunnelConnected: tunnel.snapshot.status == .connected)
                    }
                }
                .padding(16)
            }
        }
    }

    private func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak t = tunnel] in
            while !Task.isCancelled {
                if (t?.snapshot.status == .connected) {
                    await probeAllPeers()
                }
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    private func probe() {
        Task { await probeAllPeers() }
    }

    private func probeAllPeers() async {
        await withTaskGroup(of: (UUID, Int?).self) { group in
            for peer in peers {
                guard let ip = peer.reachableIP else { continue }
                group.addTask { (peer.id, await PeerPinger.firstOpenPort(host: ip)?.ms) }
            }
            for await (id, ms) in group {
                await MainActor.run { latencies[id] = ms }
            }
        }
    }
}
