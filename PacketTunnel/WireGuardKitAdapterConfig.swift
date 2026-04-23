import Foundation

/// Bridges Ultron's `WireGuardConfig` into the wg-quick text format WireGuardKit
/// expects, applying split-tunnel / kill-switch / LAN-access knobs on top of
/// the user's peer AllowedIPs.
enum WireGuardKitAdapterConfig {
    static func uapiConfig(from config: WireGuardConfig,
                           killSwitch: Bool,
                           lanAccess: Bool,
                           excluded: [String],
                           includedOverride: [String]?) -> String {
        var out = "[Interface]\n"
        out += "PrivateKey = \(config.interface.privateKeyBase64)\n"
        if !config.interface.addresses.isEmpty {
            out += "Address = \(config.interface.addresses.joined(separator: ", "))\n"
        }
        if !config.interface.dns.isEmpty {
            out += "DNS = \(config.interface.dns.joined(separator: ", "))\n"
        }
        if let mtu = config.interface.mtu {
            out += "MTU = \(mtu)\n"
        }

        for peer in config.peers {
            out += "\n[Peer]\n"
            out += "PublicKey = \(peer.publicKeyBase64)\n"
            if let psk = peer.presharedKeyBase64 {
                out += "PresharedKey = \(psk)\n"
            }
            let allowed = computeAllowedIPs(
                base: peer.allowedIPs,
                killSwitch: killSwitch,
                lanAccess: lanAccess,
                excluded: excluded,
                includedOverride: includedOverride
            )
            if !allowed.isEmpty {
                out += "AllowedIPs = \(allowed.joined(separator: ", "))\n"
            }
            if let endpoint = peer.endpoint {
                out += "Endpoint = \(endpoint)\n"
            }
            if let ka = peer.persistentKeepalive {
                out += "PersistentKeepalive = \(ka)\n"
            }
        }
        return out
    }

    private static func computeAllowedIPs(base: [String],
                                          killSwitch: Bool,
                                          lanAccess: Bool,
                                          excluded: [String],
                                          includedOverride: [String]?) -> [String] {
        if let override = includedOverride, !override.isEmpty { return override }
        var result = Set(base)
        if killSwitch {
            result.formUnion(["0.0.0.0/0", "::/0"])
        }
        if lanAccess {
            // Carve standard RFC1918 + link-local out of default routes so LAN
            // traffic bypasses the tunnel. WireGuard handles disjoint CIDRs.
            result.subtract(["192.168.0.0/16", "10.0.0.0/8", "172.16.0.0/12", "169.254.0.0/16"])
        }
        result.subtract(excluded)
        return Array(result).sorted()
    }
}
