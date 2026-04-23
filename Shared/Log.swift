import Foundation
import OSLog

enum Log {
    static let tunnel = Logger(subsystem: "com.davidwilliams.ultronvpn", category: "tunnel")
    static let ui = Logger(subsystem: "com.davidwilliams.ultronvpn", category: "ui")
    static let net = Logger(subsystem: "com.davidwilliams.ultronvpn", category: "net")
    static let config = Logger(subsystem: "com.davidwilliams.ultronvpn", category: "config")

    /// Ring-buffered text log for user-facing export. Lives in the App Group
    /// container so the Packet Tunnel extension can append to it too.
    static let ring = LogRing()
}

actor LogRing {
    private let maxLines = 4000
    private var lines: [String] = []

    private var fileURL: URL? {
        let fm = FileManager.default
        guard let container = fm.containerURL(forSecurityApplicationGroupIdentifier: SharedConstants.appGroupID) else {
            return nil
        }
        return container.appendingPathComponent("ultron.log")
    }

    func append(_ line: String, category: String = "app") {
        let ts = ISO8601DateFormatter().string(from: .now)
        let entry = "\(ts) [\(category)] \(line)"
        lines.append(entry)
        if lines.count > maxLines { lines.removeFirst(lines.count - maxLines) }
        persist()
    }

    func snapshot() -> String {
        lines.joined(separator: "\n")
    }

    func clear() {
        lines.removeAll()
        persist()
    }

    private func persist() {
        guard let url = fileURL else { return }
        try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}
