import SwiftUI

/// Free Apple-ID sideloads expire after 7 days. When >5 days have elapsed since
/// the user marked the app "installed", nag them to re-sign.
struct ProvisioningReminderCard: View {
    @Environment(Theme.self) private var theme
    @AppStorage(SharedConstants.DefaultsKey.provisioningInstalledAt, store: SharedConstants.sharedDefaults)
    private var installedAtEpoch: Double = 0

    var body: some View {
        if let card = bannerContent {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: card.icon)
                        .foregroundStyle(card.tint)
                    Text(card.title)
                        .font(.subheadline.weight(.semibold))
                }
                Text(card.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Mark resigned") {
                        installedAtEpoch = Date.now.timeIntervalSince1970
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Spacer()
                    Text(card.countdown)
                        .font(theme.monoCaption)
                        .foregroundStyle(.secondary)
                }
            }
            .card()
        }
    }

    private var bannerContent: (icon: String, title: String, body: String, tint: Color, countdown: String)? {
        let now = Date.now
        if installedAtEpoch == 0 {
            return ("clock.badge.exclamationmark",
                    "Set install date",
                    "Tap ‘Mark resigned’ after sideloading so Ultron can remind you before your 7-day signature expires.",
                    theme.warning,
                    "—")
        }
        let installed = Date(timeIntervalSince1970: installedAtEpoch)
        let elapsed = now.timeIntervalSince(installed)
        let daysLeft = 7 - (elapsed / 86_400)
        let countdown = String(format: "%.1f days left", max(0, daysLeft))

        if daysLeft <= 0 {
            return ("exclamationmark.triangle.fill",
                    "Signature expired",
                    "Re-sign Ultron with AltStore / Sideloadly / Xcode so the VPN extension can keep running.",
                    theme.danger, countdown)
        }
        if daysLeft <= 2 {
            return ("clock.badge.exclamationmark",
                    "Signature expires soon",
                    "Re-sign the app before iOS revokes the Network Extension entitlement.",
                    theme.warning, countdown)
        }
        return nil
    }
}
