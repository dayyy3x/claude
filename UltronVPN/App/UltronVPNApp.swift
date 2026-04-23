import SwiftUI
import SwiftData

@main
struct UltronVPNApp: App {
    @State private var tunnelManager = TunnelManager.shared
    @State private var theme = Theme()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(tunnelManager)
                .environment(theme)
                .preferredColorScheme(.dark)
                .tint(theme.accent)
                .task {
                    await tunnelManager.bootstrap()
                }
        }
        .modelContainer(PersistenceController.shared.container)
    }
}
