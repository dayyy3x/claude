import Foundation

enum SharedConstants {
    static let appGroupID = "group.com.davidwilliams.ultronvpn"
    static let keychainAccessGroup = "com.davidwilliams.ultronvpn"
    static let tunnelBundleID = "com.davidwilliams.ultronvpn.tunnel"
    static let tunnelProviderClass = "PacketTunnel.PacketTunnelProvider"

    static let sharedDefaultsSuite = "group.com.davidwilliams.ultronvpn"

    enum DefaultsKey {
        static let activeTunnelID = "activeTunnelID"
        static let lastHandshakeEpoch = "lastHandshakeEpoch"
        static let lastStatusRaw = "lastStatusRaw"
        static let bytesReceived = "bytesReceived"
        static let bytesSent = "bytesSent"
        static let verboseLogging = "verboseLogging"
        static let provisioningInstalledAt = "provisioningInstalledAt"
    }

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: sharedDefaultsSuite) ?? .standard
    }
}
