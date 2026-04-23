import AppIntents
import NetworkExtension
import WidgetKit

/// One intent, three surfaces: tapped from the widget, toggled from Control
/// Center, or invoked from Shortcuts. Runs in-process (`openAppWhenRun = false`)
/// so a Control Center tap doesn't bounce the user out of what they were doing.
struct ToggleTunnelIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Ultron VPN"
    static var description = IntentDescription("Connect or disconnect the last-used Ultron tunnel.")
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = true

    func perform() async throws -> some IntentResult {
        let managers = (try? await NETunnelProviderManager.loadAllFromPreferences()) ?? []
        guard let manager = pickManager(managers) else {
            throw Error.noTunnelInstalled
        }

        switch manager.connection.status {
        case .connected, .connecting, .reasserting:
            manager.connection.stopVPNTunnel()
        default:
            do {
                try manager.connection.startVPNTunnel()
            } catch {
                throw Error.startFailed(error.localizedDescription)
            }
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }

    private func pickManager(_ managers: [NETunnelProviderManager]) -> NETunnelProviderManager? {
        // Prefer whatever the app last marked as active; else the first installed.
        let last = SharedConstants.sharedDefaults.string(forKey: SharedConstants.DefaultsKey.activeTunnelID)
        if let last {
            if let m = managers.first(where: { ($0.protocolConfiguration as? NETunnelProviderProtocol)?
                .providerConfiguration?["tunnelID"] as? String == last }) {
                return m
            }
        }
        return managers.first
    }

    enum Error: Swift.Error, CustomLocalizedStringResourceConvertible {
        case noTunnelInstalled
        case startFailed(String)

        var localizedStringResource: LocalizedStringResource {
            switch self {
            case .noTunnelInstalled: return "No tunnel is installed. Open Ultron and import one first."
            case .startFailed(let m): return "Couldn’t start tunnel: \(m)"
            }
        }
    }
}

struct UltronShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleTunnelIntent(),
            phrases: [
                "Toggle \(.applicationName)",
                "Turn \(.applicationName) on",
                "Turn \(.applicationName) off",
            ],
            shortTitle: "Toggle VPN",
            systemImageName: "shield.lefthalf.filled"
        )
    }
}
