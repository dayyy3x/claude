import WidgetKit
import SwiftUI
import AppIntents

/// Control Center / Lock Screen toggle (iOS 18 ControlWidget). The same
/// `ToggleTunnelIntent` drives the Shortcuts action and the home-screen widget
/// button — one intent, three surfaces.
@available(iOS 18.0, *)
struct StatusControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "UltronToggleControl") {
            ControlWidgetToggle(
                "Ultron VPN",
                isOn: TunnelStatusStore.read().status == .connected,
                action: ToggleTunnelIntent()
            ) { isOn in
                Label(isOn ? "Protected" : "Off",
                      systemImage: isOn ? "shield.lefthalf.filled" : "shield.slash")
            }
        }
        .displayName("Ultron VPN")
        .description("Toggle the VPN tunnel from Control Center.")
    }
}
