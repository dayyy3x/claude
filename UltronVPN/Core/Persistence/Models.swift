import Foundation
import SwiftData

@Model
final class TunnelRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var lastConnectedAt: Date?
    var isOnDemand: Bool
    var killSwitch: Bool
    var lanAccess: Bool
    var configJSON: Data?            // Encoded WireGuardConfig snapshot (public parts only)
    /// Provider-side configuration is keyed by this ID in Keychain for the
    /// private key and PSKs, so nothing sensitive lives in SwiftData.
    var keychainTag: String

    init(id: UUID = UUID(),
         name: String,
         keychainTag: String,
         configJSON: Data? = nil,
         isOnDemand: Bool = false,
         killSwitch: Bool = false,
         lanAccess: Bool = true) {
        self.id = id
        self.name = name
        self.keychainTag = keychainTag
        self.configJSON = configJSON
        self.createdAt = .now
        self.isOnDemand = isOnDemand
        self.killSwitch = killSwitch
        self.lanAccess = lanAccess
    }
}

@Model
final class PeerRecord {
    @Attribute(.unique) var id: UUID
    var tunnelID: UUID
    var displayName: String
    var publicKeyBase64: String
    var endpoint: String?
    var allowedIPs: [String]
    /// IP used for latency probing / deep-link target (often first AllowedIP).
    var reachableIP: String?
    var osGlyph: String              // SF Symbol name
    var isStreamHost: Bool

    init(id: UUID = UUID(),
         tunnelID: UUID,
         displayName: String,
         publicKeyBase64: String,
         endpoint: String? = nil,
         allowedIPs: [String] = [],
         reachableIP: String? = nil,
         osGlyph: String = "pc",
         isStreamHost: Bool = false) {
        self.id = id
        self.tunnelID = tunnelID
        self.displayName = displayName
        self.publicKeyBase64 = publicKeyBase64
        self.endpoint = endpoint
        self.allowedIPs = allowedIPs
        self.reachableIP = reachableIP
        self.osGlyph = osGlyph
        self.isStreamHost = isStreamHost
    }
}

@Model
final class DeviceRecord {
    @Attribute(.unique) var id: UUID
    var hostname: String
    var lastSeen: Date
    var lastLatencyMs: Int?

    init(id: UUID = UUID(), hostname: String, lastSeen: Date = .now, lastLatencyMs: Int? = nil) {
        self.id = id
        self.hostname = hostname
        self.lastSeen = lastSeen
        self.lastLatencyMs = lastLatencyMs
    }
}
