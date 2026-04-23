import SwiftUI

struct GradientBackground: View {
    @Environment(Theme.self) private var theme
    var intensity: Double = 0.6

    var body: some View {
        ZStack {
            theme.bg
            RadialGradient(
                colors: [theme.accent.opacity(0.22 * intensity), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 520
            )
            RadialGradient(
                colors: [theme.accentGlow.opacity(0.10 * intensity), .clear],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}

struct CardBackground: ViewModifier {
    @Environment(Theme.self) private var theme

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(theme.bgElevated)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(theme.stroke, lineWidth: 1)
                    }
            }
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}
