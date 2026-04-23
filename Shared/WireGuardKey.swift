import Foundation

/// Thin wrapper around a 32-byte Curve25519 WireGuard key.
/// The `base64` form is the canonical representation used in .conf files.
struct WireGuardKey: Hashable, Sendable {
    let rawBytes: Data

    init?(base64: String) {
        let trimmed = base64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: trimmed), data.count == 32 else { return nil }
        self.rawBytes = data
    }

    init(rawBytes: Data) throws {
        guard rawBytes.count == 32 else { throw WireGuardConfigError.invalidKey }
        self.rawBytes = rawBytes
    }

    var base64: String { rawBytes.base64EncodedString() }

    /// Short public-key fingerprint for display (first 6 base64 chars).
    var shortFingerprint: String { String(base64.prefix(6)) }
}

enum WireGuardConfigError: Error, LocalizedError {
    case missingSection(String)
    case missingField(String, section: String)
    case invalidKey
    case invalidEndpoint
    case invalidAddress
    case invalidDNS
    case invalidAllowedIPs
    case empty

    var errorDescription: String? {
        switch self {
        case .missingSection(let s): return "Missing [\(s)] section"
        case .missingField(let f, let s): return "Missing \(f) in [\(s)]"
        case .invalidKey: return "Invalid WireGuard key (must be 32-byte base64)"
        case .invalidEndpoint: return "Invalid endpoint (host:port)"
        case .invalidAddress: return "Invalid Address (expected CIDR like 10.0.0.2/32)"
        case .invalidDNS: return "Invalid DNS entry"
        case .invalidAllowedIPs: return "Invalid AllowedIPs"
        case .empty: return "Empty configuration"
        }
    }
}
