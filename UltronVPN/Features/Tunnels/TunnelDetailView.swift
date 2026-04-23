import SwiftUI
import SwiftData

struct TunnelDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(TunnelManager.self) private var tunnelManager
    @Environment(Theme.self) private var theme
    let tunnelID: UUID

    @Query private var matches: [TunnelRecord]
    private var tunnel: TunnelRecord? { matches.first }

    @State private var isOnDemand = false
    @State private var killSwitch = false
    @State private var lanAccess = true
    @State private var excludedRoutes = ""

    init(tunnelID: UUID) {
        self.tunnelID = tunnelID
        let predicate = #Predicate<TunnelRecord> { $0.id == tunnelID }
        self._matches = Query(filter: predicate)
    }

    var body: some View {
        Form {
            if let tunnel {
                Section("Tunnel") {
                    LabeledContent("Name", value: tunnel.name)
                    Toggle("Connect on demand", isOn: $isOnDemand)
                    Toggle("Kill switch", isOn: $killSwitch)
                        .tint(theme.danger)
                    Toggle("Allow LAN access", isOn: $lanAccess)
                }
                Section("Split tunneling") {
                    TextField("Excluded routes (CIDRs, comma-separated)", text: $excludedRoutes)
                        .font(theme.monoCaption)
                    Text("Traffic to these CIDRs will bypass the tunnel.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let config = decodedConfig(for: tunnel) {
                    Section("Interface") {
                        ForEach(config.interface.addresses, id: \.self) { addr in
                            LabeledContent("Address", value: addr)
                                .font(theme.monoCaption)
                        }
                        ForEach(config.interface.dns, id: \.self) { dns in
                            LabeledContent("DNS", value: dns)
                                .font(theme.monoCaption)
                        }
                    }
                    Section("Peers") {
                        ForEach(config.peers) { peer in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(peer.displayName ?? peer.publicKeyBase64.prefix(10).description)
                                    .font(.body.weight(.medium))
                                if let endpoint = peer.endpoint {
                                    Text(endpoint)
                                        .font(theme.monoCaption)
                                        .foregroundStyle(.secondary)
                                }
                                Text("AllowedIPs: " + peer.allowedIPs.joined(separator: ", "))
                                    .font(theme.monoCaption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section {
                    Button("Save and reinstall") { save(tunnel) }
                        .disabled(!hasChanges(tunnel))
                    Button("Remove tunnel", role: .destructive) { remove(tunnel) }
                }
            } else {
                Text("Tunnel not found.")
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle(tunnel?.name ?? "Tunnel")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: sync)
    }

    private func sync() {
        guard let tunnel else { return }
        isOnDemand = tunnel.isOnDemand
        killSwitch = tunnel.killSwitch
        lanAccess = tunnel.lanAccess
        if let cfg = decodedConfig(for: tunnel) {
            excludedRoutes = cfg.excludedRoutes.joined(separator: ", ")
        }
    }

    private func decodedConfig(for tunnel: TunnelRecord) -> WireGuardConfig? {
        guard let data = tunnel.configJSON else { return nil }
        return try? JSONDecoder().decode(WireGuardConfig.self, from: data)
    }

    private func hasChanges(_ tunnel: TunnelRecord) -> Bool {
        isOnDemand != tunnel.isOnDemand ||
        killSwitch != tunnel.killSwitch ||
        lanAccess != tunnel.lanAccess
    }

    private func save(_ tunnel: TunnelRecord) {
        tunnel.isOnDemand = isOnDemand
        tunnel.killSwitch = killSwitch
        tunnel.lanAccess = lanAccess
        try? context.save()
        // Re-install the config with updated flags so NE picks them up.
        Task {
            guard var cfg = decodedConfig(for: tunnel) else { return }
            cfg.interface.privateKeyBase64 = (try? KeychainService.shared.string(for: "\(tunnel.keychainTag).privkey")) ?? ""
            cfg.excludedRoutes = excludedRoutes.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            try? await tunnelManager.install(tunnel: tunnel, config: cfg)
        }
    }

    private func remove(_ tunnel: TunnelRecord) {
        Task {
            try? await tunnelManager.remove(tunnel: tunnel)
            KeychainService.shared.delete(account: "\(tunnel.keychainTag).privkey")
            context.delete(tunnel)
            try? context.save()
        }
    }
}
