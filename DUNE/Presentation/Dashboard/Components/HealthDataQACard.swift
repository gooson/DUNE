import SwiftUI

struct HealthDataQACard: View {
    let isAvailable: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            InlineCard {
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    Image(systemName: "message.badge.waveform.fill")
                        .font(.title3)
                        .foregroundStyle(DS.Color.vitals)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text("Health Q&A")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)

                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(3)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dashboard-health-qa-card")
    }

    private var subtitle: String {
        if isAvailable {
            return String(localized: "Ask about sleep, recovery, and recent workouts.")
        }
        return String(localized: "Requires Apple Intelligence on a supported device.")
    }
}
