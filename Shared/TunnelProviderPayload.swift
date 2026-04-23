import Foundation

/// Payload stuffed into `NETunnelProviderProtocol.providerConfiguration`. The
/// extension reads this on startProvider and materializes a WireGuard config.
/// Secrets (private key, PSKs) are *not* in the payload — they live in the
/// shared Keychain access group and are fetched by `keychainTag`.
struct TunnelProviderPayload: Codable, Sendable {
    var tunnelID: UUID
    var tunnelName: String
    var config: WireGuardConfig
    var keychainTag: String
    var killSwitch: Bool
    var lanAccess: Bool
    var excludedRoutes: [String]
    var includedRoutesOverride: [String]?

    func encodeForProvider() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        return [
            "tunnelID": tunnelID.uuidString,
            "tunnelName": tunnelName,
            "payload": data,
        ]
    }

    static func decode(from dict: [String: Any]) throws -> TunnelProviderPayload {
        guard let data = dict["payload"] as? Data else {
            throw WireGuardConfigError.empty
        }
        return try JSONDecoder().decode(TunnelProviderPayload.self, from: data)
    }
}
