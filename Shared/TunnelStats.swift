import Foundation

struct TunnelStats: Codable, Sendable, Equatable {
    var bytesReceived: UInt64
    var bytesSent: UInt64
    var throughputRxBps: UInt64
    var throughputTxBps: UInt64
    var lastHandshake: Date?
    var rttMs: Int?
    var degraded: Bool

    static let zero = TunnelStats(
        bytesReceived: 0, bytesSent: 0,
        throughputRxBps: 0, throughputTxBps: 0,
        lastHandshake: nil, rttMs: nil, degraded: false
    )
}

/// Strongly-typed IPC between the app and the Packet Tunnel extension. Sent as
/// JSON over `NETunnelProviderSession.sendProviderMessage`.
enum TunnelProviderMessage: Codable, Sendable {
    case stats
    case setVerboseLogging(Bool)
    case exportLog

    var encoded: Data { (try? JSONEncoder().encode(self)) ?? Data() }
}
