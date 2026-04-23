import SwiftUI

/// Animated status ring driven by TimelineView + Canvas so it keeps breathing
/// without round-tripping through SwiftUI's diff on every frame.
struct ConnectRingView: View {
    @Environment(Theme.self) private var theme
    let status: TunnelStatusSnapshot.Status
    let isBusy: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let rect = CGRect(origin: .zero, size: size).insetBy(dx: 14, dy: 14)
                let center = CGPoint(x: rect.midX, y: rect.midY)
                let r = min(rect.width, rect.height) / 2

                // Outer glow
                let glow = Path(ellipseIn: rect.insetBy(dx: -6, dy: -6))
                ctx.addFilter(.blur(radius: pulse(t) * 12 + 4))
                ctx.stroke(glow, with: .color(color.opacity(0.35)), lineWidth: 2)

                // Base ring
                let base = Path(ellipseIn: rect)
                var baseCtx = ctx
                baseCtx.addFilter(.blur(radius: 0))
                baseCtx.stroke(base, with: .color(color.opacity(0.2)), lineWidth: 3)

                // Active arc
                let sweep = arcSweep(t)
                let arc = Path { p in
                    p.addArc(center: center,
                             radius: r,
                             startAngle: .degrees(-90 + rotation(t)),
                             endAngle: .degrees(-90 + rotation(t) + sweep),
                             clockwise: false)
                }
                var arcCtx = ctx
                arcCtx.addFilter(.blur(radius: 0))
                arcCtx.stroke(arc,
                              with: .linearGradient(
                                  Gradient(colors: [color, color.opacity(0.3)]),
                                  startPoint: CGPoint(x: rect.minX, y: rect.minY),
                                  endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                              ),
                              style: StrokeStyle(lineWidth: 5, lineCap: .round))

                // Inner pulse
                let inner = Path(ellipseIn: rect.insetBy(dx: r * 0.5, dy: r * 0.5))
                ctx.fill(inner, with: .color(color.opacity(0.08 + pulse(t) * 0.08)))
            }
        }
        .frame(width: 260, height: 260)
        .animation(.spring(duration: 0.6), value: status)
    }

    private var color: Color { theme.statusColor(status) }

    private func arcSweep(_ t: TimeInterval) -> Double {
        switch status {
        case .disconnected: return 30
        case .handshaking:  return 120 + sin(t * 4) * 30
        case .connected:    return 360
        case .degraded:     return 260 + sin(t * 2) * 40
        case .failed:       return 40
        }
    }

    private func rotation(_ t: TimeInterval) -> Double {
        switch status {
        case .handshaking: return (t * 180).truncatingRemainder(dividingBy: 360)
        case .degraded:    return (t * 40).truncatingRemainder(dividingBy: 360)
        case .connected:   return (t * 8).truncatingRemainder(dividingBy: 360)
        default:           return 0
        }
    }

    private func pulse(_ t: TimeInterval) -> CGFloat {
        switch status {
        case .connected:   return 0.5 + 0.5 * CGFloat(sin(t * 2.0))
        case .handshaking: return 0.5 + 0.5 * CGFloat(sin(t * 5.0))
        case .degraded:    return 0.5 + 0.5 * CGFloat(sin(t * 1.2))
        default:           return 0
        }
    }
}
