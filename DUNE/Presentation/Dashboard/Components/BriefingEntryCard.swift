import SwiftUI

/// Compact card below hero that opens the morning briefing sheet.
struct BriefingEntryCard: View {
    let conditionStatus: ConditionScore.Status
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            InlineCard {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "sun.horizon.fill")
                        .font(.title3)
                        .foregroundStyle(statusColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Morning Briefing")
                            .font(.subheadline.weight(.semibold))

                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Morning Briefing, \(subtitle)"))
        .accessibilityHint(Text("Opens your daily briefing"))
        .accessibilityIdentifier("briefing-entry-card")
    }

    private var subtitle: String {
        switch conditionStatus {
        case .excellent: String(localized: "Excellent day ahead")
        case .good: String(localized: "Good day ahead")
        case .fair: String(localized: "Take it easy today")
        case .tired: String(localized: "Rest is important today")
        case .warning: String(localized: "Recovery day")
        }
    }

    private var statusColor: Color {
        conditionStatus.color
    }
}
