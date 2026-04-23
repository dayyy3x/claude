import SwiftUI
import SwiftData

struct TunnelsView: View {
    @Environment(Theme.self) private var theme
    @Environment(TunnelManager.self) private var tunnelManager
    @Environment(\.modelContext) private var context
    @Query(sort: \TunnelRecord.createdAt, order: .reverse) private var tunnels: [TunnelRecord]

    @State private var showingImport = false

    var body: some View {
        NavigationStack {
            ZStack {
                GradientBackground(intensity: 0.35)
                content
            }
            .navigationTitle("Tunnels")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingImport = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingImport) {
                ImportTunnelView()
                    .presentationDetents([.medium, .large])
            }
        }
    }

    @ViewBuilder private var content: some View {
        if tunnels.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 48))
                    .foregroundStyle(theme.accent.opacity(0.8))
                Text("No tunnels yet")
                    .font(.title3.weight(.semibold))
                Text("Import a WireGuard or Tailscale/Headscale configuration.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Import") { showingImport = true }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 4)
            }
            .padding(32)
        } else {
            List {
                ForEach(tunnels) { t in
                    NavigationLink {
                        TunnelDetailView(tunnelID: t.id)
                    } label: {
                        TunnelRow(tunnel: t)
                    }
                    .listRowBackground(theme.bgElevated)
                }
                .onDelete(perform: delete)
            }
            .scrollContentBackground(.hidden)
        }
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets {
            let t = tunnels[index]
            Task {
                try? await tunnelManager.remove(tunnel: t)
                context.delete(t)
                try? context.save()
            }
        }
    }
}

private struct TunnelRow: View {
    @Environment(Theme.self) private var theme
    @Environment(TunnelManager.self) private var manager
    let tunnel: TunnelRecord

    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundStyle(theme.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(tunnel.name)
                    .font(.body.weight(.medium))
                if let endpoint = firstEndpoint {
                    Text(endpoint)
                        .font(theme.monoCaption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isActive {
                Text("Active")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(theme.accentSoft, in: Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        tunnel.isOnDemand ? "bolt.shield.fill" : "shield.lefthalf.filled"
    }

    private var firstEndpoint: String? {
        guard let data = tunnel.configJSON,
              let cfg = try? JSONDecoder().decode(WireGuardConfig.self, from: data)
        else { return nil }
        return cfg.peers.first?.endpoint
    }

    private var isActive: Bool {
        manager.snapshot.tunnelID == tunnel.id.uuidString && manager.snapshot.status == .connected
    }
}
