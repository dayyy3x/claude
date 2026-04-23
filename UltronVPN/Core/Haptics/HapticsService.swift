import CoreHaptics
import UIKit

@MainActor
final class HapticsService {
    static let shared = HapticsService()

    private var engine: CHHapticEngine?

    private init() {
        prepare()
    }

    private func prepare() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            Log.ui.warning("Haptic engine start failed: \(error.localizedDescription)")
        }
    }

    func connectThump() {
        play(sharpness: 0.9, intensity: 1.0, duration: 0.08)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            self.play(sharpness: 0.3, intensity: 0.55, duration: 0.18)
        }
    }

    func disconnectTap() {
        play(sharpness: 0.7, intensity: 0.6, duration: 0.06)
    }

    func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    private func play(sharpness: Float, intensity: Float, duration: TimeInterval) {
        guard let engine else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return
        }
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: 0,
            duration: duration
        )
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
}
