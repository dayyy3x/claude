import Foundation
import NetworkExtension
import OSLog
import WireGuardKit

/// Packet Tunnel Provider that wires WireGuardKit's adapter into the iOS
/// NetworkExtension data path. Everything runs inside the extension's sandbox,
/// so we have no UIKit access — state is surfaced back to the app via
/// `sendProviderMessage` replies and the shared App Group defaults.
final class PacketTunnelProvider: NEPacketTunnelProvider {
    private let logger = Logger(subsystem: "com.davidwilliams.ultronvpn.tunnel", category: "provider")

    private lazy var adapter: WireGuardAdapter = {
        WireGuardAdapter(with: self) { [weak self] level, message in
            self?.logger.log(level: level.osLogType, "\(message, privacy: .public)")
            Task { await self?.append(logLine: "[\(level.label)] \(message)") }
        }
    }()

    private var statsStart = Date()
    private var lastRx: UInt64 = 0
    private var lastTx: UInt64 = 0
    private var lastPoll = Date()

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        logger.info("startTunnel invoked")
        guard let proto = protocolConfiguration as? NETunnelProviderProtocol,
              let providerConfig = proto.providerConfiguration,
              let payload = try? TunnelProviderPayload.decode(from: providerConfig)
        else {
            completionHandler(ProviderError.missingConfiguration)
            return
        }

        // Fetch private key + PSKs from the shared Keychain.
        let privateKeyB64: String
        do {
            privateKeyB64 = try KeychainService.shared.string(for: "\(payload.keychainTag).privkey")
        } catch {
            logger.error("Missing private key in keychain for tag \(payload.keychainTag)")
            completionHandler(ProviderError.missingPrivateKey); return
        }

        var config = payload.config
        config.interface.privateKeyBase64 = privateKeyB64
        for i in 0..<config.peers.count {
            if let psk = try? KeychainService.shared.string(for: "\(payload.keychainTag).psk.\(config.peers[i].id.uuidString)") {
                config.peers[i].presharedKeyBase64 = psk
            }
        }

        let tunnelConfiguration: TunnelConfiguration
        do {
            let wgConfig = WireGuardKitAdapterConfig.uapiConfig(from: config,
                                                                 killSwitch: payload.killSwitch,
                                                                 lanAccess: payload.lanAccess,
                                                                 excluded: payload.excludedRoutes,
                                                                 includedOverride: payload.includedRoutesOverride)
            tunnelConfiguration = try TunnelConfiguration(fromWgQuickConfig: wgConfig)
        } catch {
            completionHandler(ProviderError.invalidConfiguration(error.localizedDescription))
            return
        }

        adapter.start(tunnelConfiguration: tunnelConfiguration) { [weak self] error in
            guard let self else { return }
            if let error {
                self.logger.error("WireGuardAdapter start error: \(error.localizedDescription, privacy: .public)")
                completionHandler(error); return
            }
            self.publishSnapshot(.connected, payload: payload)
            completionHandler(nil)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.info("stopTunnel reason=\(reason.rawValue)")
        adapter.stop { [weak self] _ in
            self?.publishSnapshot(.disconnected, payload: nil)
            completionHandler()
        }
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        guard let msg = try? JSONDecoder().decode(TunnelProviderMessage.self, from: messageData) else {
            completionHandler?(nil); return
        }
        switch msg {
        case .stats:
            let stats = sampleStats()
            completionHandler?(try? JSONEncoder().encode(stats))
        case .setVerboseLogging(let on):
            logger.info("verbose logging \(on)")
            completionHandler?(nil)
        case .exportLog:
            completionHandler?(nil)
        }
    }

    // MARK: - Stats

    private func sampleStats() -> TunnelStats {
        let now = Date()
        let delta = max(now.timeIntervalSince(lastPoll), 0.001)
        var result = TunnelStats.zero
        adapter.getRuntimeConfiguration { cfg in
            guard let cfg else { return }
            // Extract per-peer rx/tx totals from the UAPI-style config blob.
            let (rx, tx, handshakeEpoch) = Self.parseTotals(from: cfg)
            result = TunnelStats(
                bytesReceived: rx,
                bytesSent: tx,
                throughputRxBps: UInt64(max(0, Double(rx &- self.lastRx) / delta)),
                throughputTxBps: UInt64(max(0, Double(tx &- self.lastTx) / delta)),
                lastHandshake: handshakeEpoch.map { Date(timeIntervalSince1970: TimeInterval($0)) },
                rttMs: nil,
                degraded: handshakeEpoch.map { now.timeIntervalSince1970 - TimeInterval($0) > 180 } ?? false
            )
            self.lastRx = rx; self.lastTx = tx; self.lastPoll = now
        }
        return result
    }

    private static func parseTotals(from uapi: String) -> (UInt64, UInt64, UInt64?) {
        var rx: UInt64 = 0, tx: UInt64 = 0, hs: UInt64? = nil
        for line in uapi.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            switch parts[0] {
            case "rx_bytes": rx &+= UInt64(parts[1]) ?? 0
            case "tx_bytes": tx &+= UInt64(parts[1]) ?? 0
            case "last_handshake_time_sec":
                if let v = UInt64(parts[1]), v > 0 { hs = max(hs ?? 0, v) }
            default: break
            }
        }
        return (rx, tx, hs)
    }

    // MARK: - Shared-state publish

    private func publishSnapshot(_ status: TunnelStatusSnapshot.Status, payload: TunnelProviderPayload?) {
        let snap = TunnelStatusSnapshot(
            status: status,
            tunnelID: payload?.tunnelID.uuidString,
            tunnelName: payload?.tunnelName,
            lastHandshake: nil,
            bytesReceived: 0,
            bytesSent: 0,
            updatedAt: .now
        )
        TunnelStatusStore.write(snap)
    }

    private func append(logLine: String) async {
        await Log.ring.append(logLine, category: "tunnel")
    }
}

enum ProviderError: LocalizedError {
    case missingConfiguration
    case missingPrivateKey
    case invalidConfiguration(String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration: return "Tunnel provider configuration is missing."
        case .missingPrivateKey:    return "Private key is missing from the keychain."
        case .invalidConfiguration(let m): return "Invalid tunnel configuration: \(m)"
        }
    }
}

private extension WireGuardLogLevel {
    var osLogType: OSLogType {
        switch self {
        case .verbose: return .debug
        case .error:   return .error
        }
    }
    var label: String {
        switch self {
        case .verbose: return "verbose"
        case .error:   return "error"
        }
    }
}
