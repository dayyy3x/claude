import SwiftUI

struct RootView: View {
    enum Tab: Hashable { case home, devices, tunnels, settings }

    @State private var selection: Tab = .home

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("Home", systemImage: "shield.lefthalf.filled") }
                .tag(Tab.home)

            DevicesView()
                .tabItem { Label("Devices", systemImage: "display.2") }
                .tag(Tab.devices)

            TunnelsView()
                .tabItem { Label("Tunnels", systemImage: "point.3.connected.trianglepath.dotted") }
                .tag(Tab.tunnels)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
    }
}
