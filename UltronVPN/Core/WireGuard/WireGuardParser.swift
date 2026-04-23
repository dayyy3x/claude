import Foundation

/// Parses wg-quick `.conf` files. Permissive about whitespace and comments but
/// strict enough to reject malformed keys / endpoints early with a useful error.
enum WireGuardParser {
    static func parse(_ text: String) throws -> WireGuardConfig {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WireGuardConfigError.empty
        }

        var section: String? = nil
        var currentPeerComment: String? = nil

        var interface: [String: String] = [:]
        var peers: [[String: String]] = []
        var peerComments: [String?] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if line.hasPrefix("#") {
                // Preserve the *last* comment before a [Peer] to use as display name.
                currentPeerComment = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                continue
            }

            if line.hasPrefix("[") && line.hasSuffix("]") {
                let name = String(line.dropFirst().dropLast()).lowercased()
                section = name
                if name == "peer" {
                    peers.append([:])
                    peerComments.append(currentPeerComment)
                    currentPeerComment = nil
                }
                continue
            }

            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)

            switch section {
            case "interface":
                interface[key] = value
            case "peer":
                peers[peers.count - 1][key] = value
            default:
                continue
            }
        }

        guard !interface.isEmpty else { throw WireGuardConfigError.missingSection("Interface") }
        guard let priv = interface["privatekey"], !priv.isEmpty else {
            throw WireGuardConfigError.missingField("PrivateKey", section: "Interface")
        }
        guard WireGuardKey(base64: priv) != nil else { throw WireGuardConfigError.invalidKey }

        let addresses = splitCSV(interface["address"])
        let dns = splitCSV(interface["dns"])
        try addresses.forEach { try validateCIDR($0) }

        let iface = WireGuardConfig.Interface(
            privateKeyBase64: priv,
            addresses: addresses,
            dns: dns,
            mtu: interface["mtu"].flatMap(Int.init),
            listenPort: interface["listenport"].flatMap(Int.init)
        )

        var parsedPeers: [WireGuardConfig.Peer] = []
        for (idx, raw) in peers.enumerated() {
            guard let pub = raw["publickey"] else {
                throw WireGuardConfigError.missingField("PublicKey", section: "Peer")
            }
            guard WireGuardKey(base64: pub) != nil else { throw WireGuardConfigError.invalidKey }

            let allowed = splitCSV(raw["allowedips"])
            try allowed.forEach { try validateCIDR($0) }

            let endpoint = raw["endpoint"]
            if let ep = endpoint, !ep.isEmpty { try validateEndpoint(ep) }

            if let psk = raw["presharedkey"], WireGuardKey(base64: psk) == nil {
                throw WireGuardConfigError.invalidKey
            }

            parsedPeers.append(.init(
                publicKeyBase64: pub,
                presharedKeyBase64: raw["presharedkey"],
                endpoint: endpoint,
                allowedIPs: allowed,
                persistentKeepalive: raw["persistentkeepalive"].flatMap(Int.init),
                displayName: peerComments[idx],
                note: nil
            ))
        }

        return WireGuardConfig(interface: iface, peers: parsedPeers)
    }

    private static func splitCSV(_ s: String?) -> [String] {
        guard let s, !s.isEmpty else { return [] }
        return s.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func validateCIDR(_ s: String) throws {
        let parts = s.split(separator: "/")
        guard parts.count == 2, Int(parts[1]) != nil else { throw WireGuardConfigError.invalidAddress }
        // Host portion: let NE validate in depth; we do a lightweight sanity check.
        let host = String(parts[0])
        if host.contains(":") {
            // IPv6 — accept if it roughly looks like one.
            if host.filter({ $0 == ":" }).count < 2 { throw WireGuardConfigError.invalidAddress }
        } else {
            let octets = host.split(separator: ".")
            guard octets.count == 4 else { throw WireGuardConfigError.invalidAddress }
            for o in octets {
                guard let n = Int(o), (0...255).contains(n) else { throw WireGuardConfigError.invalidAddress }
            }
        }
    }

    private static func validateEndpoint(_ s: String) throws {
        // Accept host:port or [v6]:port.
        if s.hasPrefix("[") {
            guard let close = s.firstIndex(of: "]"),
                  s.index(after: close) < s.endIndex,
                  s[s.index(after: close)] == ":",
                  let port = Int(s[s.index(close, offsetBy: 2)...]),
                  (1...65535).contains(port)
            else { throw WireGuardConfigError.invalidEndpoint }
            return
        }
        guard let colon = s.lastIndex(of: ":") else { throw WireGuardConfigError.invalidEndpoint }
        let host = String(s[..<colon])
        guard let port = Int(s[s.index(after: colon)...]),
              (1...65535).contains(port),
              !host.isEmpty
        else { throw WireGuardConfigError.invalidEndpoint }
    }
}
