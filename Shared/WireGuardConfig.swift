import Foundation

/// Parsed representation of a WireGuard configuration file. Intentionally a
/// value type so it can be Codable and safely passed through the tunnel
/// provider's protocolConfiguration.providerConfiguration dictionary.
struct WireGuardConfig: Codable, Sendable, Hashable {
    struct Interface: Codable, Sendable, Hashable {
        var privateKeyBase64: String
        var addresses: [String]          // e.g. ["10.0.0.2/32", "fd7a:115c::2/128"]
        var dns: [String]                // e.g. ["1.1.1.1", "https://dns.quad9.net/dns-query"]
        var mtu: Int?
        var listenPort: Int?
    }

    struct Peer: Codable, Sendable, Hashable, Identifiable {
        var id: UUID = UUID()
        var publicKeyBase64: String
        var presharedKeyBase64: String?
        var endpoint: String?            // host:port
        var allowedIPs: [String]         // CIDRs
        var persistentKeepalive: Int?
        var displayName: String?
        var note: String?

        enum CodingKeys: String, CodingKey {
            case id, publicKeyBase64, presharedKeyBase64, endpoint, allowedIPs, persistentKeepalive, displayName, note
        }
    }

    var interface: Interface
    var peers: [Peer]

    // UI / bookkeeping
    var excludedRoutes: [String] = []
    var includedRoutesOverride: [String]? = nil
    var lanAccess: Bool = true

    /// Round-trip a parsed config back to .conf text (lossy: drops UI-only fields).
    func toWGQuickText() -> String {
        var out = "[Interface]\n"
        out += "PrivateKey = \(interface.privateKeyBase64)\n"
        if !interface.addresses.isEmpty {
            out += "Address = \(interface.addresses.joined(separator: ", "))\n"
        }
        if !interface.dns.isEmpty {
            out += "DNS = \(interface.dns.joined(separator: ", "))\n"
        }
        if let mtu = interface.mtu { out += "MTU = \(mtu)\n" }
        if let port = interface.listenPort { out += "ListenPort = \(port)\n" }

        for peer in peers {
            out += "\n[Peer]\n"
            if let name = peer.displayName { out += "# \(name)\n" }
            out += "PublicKey = \(peer.publicKeyBase64)\n"
            if let psk = peer.presharedKeyBase64 { out += "PresharedKey = \(psk)\n" }
            if !peer.allowedIPs.isEmpty {
                out += "AllowedIPs = \(peer.allowedIPs.joined(separator: ", "))\n"
            }
            if let endpoint = peer.endpoint { out += "Endpoint = \(endpoint)\n" }
            if let ka = peer.persistentKeepalive { out += "PersistentKeepalive = \(ka)\n" }
        }
        return out
    }
}
