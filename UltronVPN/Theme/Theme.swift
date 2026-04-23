import SwiftUI

@Observable
final class Theme {
    // Deep teal — committed.
    let accent = Color(red: 0.09, green: 0.72, blue: 0.74)
    let accentSoft = Color(red: 0.09, green: 0.72, blue: 0.74).opacity(0.18)
    let accentGlow = Color(red: 0.20, green: 0.92, blue: 0.92)

    let danger = Color(red: 0.95, green: 0.35, blue: 0.38)
    let warning = Color(red: 0.98, green: 0.73, blue: 0.23)
    let success = Color(red: 0.35, green: 0.85, blue: 0.60)

    let bg = Color(red: 0.04, green: 0.06, blue: 0.08)
    let bgElevated = Color(red: 0.07, green: 0.09, blue: 0.12)
    let stroke = Color.white.opacity(0.06)

    let monoDigits: Font = .system(.title3, design: .monospaced, weight: .medium)
    let monoCaption: Font = .system(.caption, design: .monospaced, weight: .regular)

    func statusColor(_ status: TunnelStatusSnapshot.Status) -> Color {
        switch status {
        case .disconnected: return Color.white.opacity(0.45)
        case .handshaking:  return warning
        case .connected:    return accent
        case .degraded:     return Color(red: 0.95, green: 0.55, blue: 0.25)
        case .failed:       return danger
        }
    }
}
