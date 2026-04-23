import Foundation
import NetworkExtension
import Observation

/// Orchestrates NETunnelProviderManager instances — one per installed tunnel
/// config — and publishes a live status snapshot for the UI and widget.
@MainActor
@Observable
final class TunnelManager {
    static let shared = TunnelManager()

    enum ActivationError: LocalizedError {
        case notInstalled
        case keysMissing
        case startFailed(String)

        var errorDescription: String? {
            switch self {
            case .notInstalled: return "Tunnel is not installed on this device."
            case .keysMissing: return "Private key is missing from the keychain."
            case .startFailed(let m): return "Could not start tunnel: \(m)"
            }
        }
    }

    private(set) var snapshot: TunnelStatusSnapshot = .disconnected
    private(set) var stats: TunnelStats = .zero
    private(set) var activeTunnelID: UUID?
    private(set) var managers: [NETunnelProviderManager] = []
    private(set) var isBusy: Bool = false
    var lastError: String?

    private var statsTimer: Task<Void, Never>?
    private var statusObserver: NSObjectProtocol?

    private init() {}

    // MARK: - Lifecycle

    func bootstrap() async {
        await reloadManagers()
        attachStatusObserver()
        refreshSnapshot()
        startStatsPump()
    }

    // MARK: - Manager CRUD

    func reloadManagers() async {
        do {
            managers = try await NETunnelProviderManager.loadAllFromPreferences()
            Log.tunnel.info("Loaded \(self.managers.count) tunnel manager(s).")
        } catch {
            Log.tunnel.error("loadAllFromPreferences failed: \(error.localizedDescription)")
        }
    }

    func install(tunnel: TunnelRecord, config: WireGuardConfig) async throws {
        let manager = existingManager(for: tunnel.id) ?? NETunnelProviderManager()
        manager.localizedDescription = tunnel.name

        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = SharedConstants.tunnelBundleID
        // Tunnels connect to the first peer's endpoint by default; NE requires
        // a serverAddress string for the config row in Settings.
        proto.serverAddress = config.peers.first?.endpoint ?? "wireguard"
        proto.disconnectOnSleep = false
        // Kill-switch: route all traffic through the tunnel with no leaks.
        proto.includeAllNetworks = tunnel.killSwitch
        proto.excludeLocalNetworks = !tunnel.lanAccess

        let payload = TunnelProviderPayload(
            tunnelID: tunnel.id,
            tunnelName: tunnel.name,
            config: config,
            keychainTag: tunnel.keychainTag,
            killSwitch: tunnel.killSwitch,
            lanAccess: tunnel.lanAccess,
            excludedRoutes: config.excludedRoutes,
            includedRoutesOverride: config.includedRoutesOverride
        )
        proto.providerConfiguration = try payload.encodeForProvider()

        manager.protocolConfiguration = proto
        manager.isEnabled = true

        if tunnel.isOnDemand {
            let wifiRule = NEOnDemandRuleConnect()
            wifiRule.interfaceTypeMatch = .wiFi
            let cellRule = NEOnDemandRuleConnect()
            cellRule.interfaceTypeMatch = .cellular
            manager.onDemandRules = [wifiRule, cellRule]
            manager.isOnDemandEnabled = true
        } else {
            manager.onDemandRules = []
            manager.isOnDemandEnabled = false
        }

        try await manager.saveToPreferences()
        try await manager.loadFromPreferences()
        await reloadManagers()
    }

    func remove(tunnel: TunnelRecord) async throws {
        guard let manager = existingManager(for: tunnel.id) else { return }
        try await manager.removeFromPreferences()
        await reloadManagers()
    }

    // MARK: - Connect / disconnect

    func connect(tunnelID: UUID) async throws {
        guard let manager = existingManager(for: tunnelID) else { throw ActivationError.notInstalled }
        isBusy = true
        defer { isBusy = false }
        do {
            try manager.connection.startVPNTunnel()
            activeTunnelID = tunnelID
            SharedConstants.sharedDefaults.set(tunnelID.uuidString, forKey: SharedConstants.DefaultsKey.activeTunnelID)
            await Log.ring.append("Started tunnel \(manager.localizedDescription ?? tunnelID.uuidString)", category: "tunnel")
            HapticsService.shared.connectThump()
        } catch {
            lastError = error.localizedDescription
            HapticsService.shared.warning()
            throw ActivationError.startFailed(error.localizedDescription)
        }
    }

    func disconnect() async {
        guard let session = activeSession else { return }
        session.stopVPNTunnel()
        await Log.ring.append("Stopped tunnel", category: "tunnel")
        HapticsService.shared.disconnectTap()
    }

    func toggle() async {
        if snapshot.status == .connected || snapshot.status == .handshaking {
            await disconnect()
        } else if let id = activeTunnelID ?? preferredTunnelID() {
            try? await connect(tunnelID: id)
        }
    }

    // MARK: - Queries

    func existingManager(for id: UUID) -> NETunnelProviderManager? {
        managers.first { ($0.protocolConfiguration as? NETunnelProviderProtocol)?
            .providerConfiguration?["tunnelID"] as? String == id.uuidString }
    }

    var activeSession: NETunnelProviderSession? {
        managers.lazy
            .compactMap { $0.connection as? NETunnelProviderSession }
            .first { $0.status != .invalid && $0.status != .disconnected }
    }

    private func preferredTunnelID() -> UUID? {
        if let s = SharedConstants.sharedDefaults.string(forKey: SharedConstants.DefaultsKey.activeTunnelID),
           let id = UUID(uuidString: s) { return id }
        let first = (managers.first?.protocolConfiguration as? NETunnelProviderProtocol)?
            .providerConfiguration?["tunnelID"] as? String
        return first.flatMap(UUID.init(uuidString:))
    }

    // MARK: - Observation

    private func attachStatusObserver() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshSnapshot() }
        }
    }

    private func refreshSnapshot() {
        let session = managers.lazy
            .compactMap { $0.connection as? NETunnelProviderSession }
            .max(by: { statusRank($0.status) < statusRank($1.status) })

        let status: TunnelStatusSnapshot.Status = {
            switch session?.status ?? .disconnected {
            case .connected:     return .connected
            case .connecting, .reasserting: return .handshaking
            case .disconnecting: return .handshaking
            case .disconnected, .invalid: return .disconnected
            @unknown default:    return .disconnected
            }
        }()

        let manager = session.flatMap { s in managers.first { ($0.connection as? NETunnelProviderSession) === s } }
        let providerTunnelID = (manager?.protocolConfiguration as? NETunnelProviderProtocol)?
            .providerConfiguration?["tunnelID"] as? String

        snapshot = TunnelStatusSnapshot(
            status: status,
            tunnelID: providerTunnelID,
            tunnelName: manager?.localizedDescription,
            lastHandshake: snapshot.lastHandshake,
            bytesReceived: snapshot.bytesReceived,
            bytesSent: snapshot.bytesSent,
            updatedAt: .now
        )
        TunnelStatusStore.write(snapshot)
    }

    // MARK: - Stats pump

    private func startStatsPump() {
        statsTimer?.cancel()
        statsTimer = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollStats()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func pollStats() async {
        guard let session = activeSession,
              session.status == .connected else {
            stats = .zero
            return
        }
        // Ask the provider for a stats blob. The extension responds on
        // TunnelProviderMessage.stats.
        let message = TunnelProviderMessage.stats.encoded
        do {
            try session.sendProviderMessage(message) { [weak self] data in
                guard let self, let data,
                      let reply = try? JSONDecoder().decode(TunnelStats.self, from: data)
                else { return }
                Task { @MainActor in
                    self.stats = reply
                    self.snapshot.bytesReceived = reply.bytesReceived
                    self.snapshot.bytesSent = reply.bytesSent
                    self.snapshot.lastHandshake = reply.lastHandshake
                    self.snapshot.status = reply.degraded ? .degraded : .connected
                    self.snapshot.updatedAt = .now
                    TunnelStatusStore.write(self.snapshot)
                }
            }
        } catch {
            Log.tunnel.debug("stats IPC failed: \(error.localizedDescription)")
        }
    }
}

private func statusRank(_ s: NEVPNStatus) -> Int {
    switch s {
    case .connected:     return 4
    case .connecting, .reasserting: return 3
    case .disconnecting: return 2
    case .disconnected:  return 1
    case .invalid:       return 0
    @unknown default:    return 0
    }
}
