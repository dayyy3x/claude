import Foundation

/// Minimal, Codable snapshot of tunnel state that the app, widget, and extension
/// can all read/write through the shared UserDefaults suite.
struct TunnelStatusSnapshot: Codable, Sendable, Equatable {
    enum Status: String, Codable, Sendable {
        case disconnected
        case handshaking
        case connected
        case degraded
        case failed
    }

    var status: Status
    var tunnelID: String?
    var tunnelName: String?
    var lastHandshake: Date?
    var bytesReceived: UInt64
    var bytesSent: UInt64
    var updatedAt: Date

    static let disconnected = TunnelStatusSnapshot(
        status: .disconnected,
        tunnelID: nil,
        tunnelName: nil,
        lastHandshake: nil,
        bytesReceived: 0,
        bytesSent: 0,
        updatedAt: .now
    )
}

enum TunnelStatusStore {
    private static let key = "tunnelStatusSnapshot"

    static func read() -> TunnelStatusSnapshot {
        guard let data = SharedConstants.sharedDefaults.data(forKey: key),
              let snap = try? JSONDecoder().decode(TunnelStatusSnapshot.self, from: data)
        else { return .disconnected }
        return snap
    }

    static func write(_ snap: TunnelStatusSnapshot) {
        guard let data = try? JSONEncoder().encode(snap) else { return }
        SharedConstants.sharedDefaults.set(data, forKey: key)
    }
}
