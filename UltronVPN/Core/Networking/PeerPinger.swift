import Foundation
import Network

/// Measures reachability of a peer over the tunnel via a low-cost TCP connect
/// attempt to a likely-open port (SSH / RDP / HTTPS). Returns ms on success,
/// nil on failure. We deliberately avoid ICMP since iOS doesn't allow raw
/// sockets from app-sandboxed processes.
struct PeerPinger {
    static func latency(to host: String, port: UInt16 = 22, timeout: TimeInterval = 1.2) async -> Int? {
        await withCheckedContinuation { (cont: CheckedContinuation<Int?, Never>) in
            let nwHost = NWEndpoint.Host(host)
            let nwPort = NWEndpoint.Port(rawValue: port) ?? .any
            let connection = NWConnection(host: nwHost, port: nwPort, using: .tcp)

            let start = DispatchTime.now()
            var resumed = false
            let resume: (Int?) -> Void = { value in
                if !resumed {
                    resumed = true
                    connection.cancel()
                    cont.resume(returning: value)
                }
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let ms = Int(Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)
                    resume(ms)
                case .failed, .cancelled:
                    resume(nil)
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .utility))

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { resume(nil) }
        }
    }

    /// Probe a handful of typical host ports and return the first success.
    static func firstOpenPort(host: String, ports: [UInt16] = [47989, 3389, 22, 5900, 443]) async -> (port: UInt16, ms: Int)? {
        for port in ports {
            if let ms = await latency(to: host, port: port, timeout: 0.8) {
                return (port, ms)
            }
        }
        return nil
    }
}
