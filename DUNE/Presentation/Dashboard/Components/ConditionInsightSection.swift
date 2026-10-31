import SwiftUI

/// Shows contextual interpretation and activity guidance based on condition score status.
struct ConditionInsightSection: View {
    let status: ConditionScore.Status

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { _ in
            content(period: LocalDayPeriod(date: DashboardClock.now()))
        }
    }

    private func content(period: LocalDayPeriod) -> some View {
        let guidance = ConditionInsightGuidance.message(status: status, period: period)
        return VStack(alignment: .leading, spacing: isRegular ? DS.Spacing.md : DS.Spacing.sm) {
            Text("Today's Insight")
                .font(isRegular ? .headline : .subheadline)
                .fontWeight(.semibold)

            InlineCard {
                HStack(alignment: .top, spacing: isRegular ? DS.Spacing.lg : DS.Spacing.md) {
                    Image(systemName: status.iconName)
                        .font(isRegular ? .title : .title2)
                        .foregroundStyle(status.color)
                        .frame(width: isRegular ? 36 : 32)

                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text(interpretation)
                            .font(isRegular ? .body : .subheadline)
                            .fontWeight(.medium)

                        Text(guidance)
                            .font(isRegular ? .subheadline : .caption)
                            .foregroundStyle(DS.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.label), \(interpretation), \(guidance)")
    }

    // MARK: - Content

    private var interpretation: String {
        switch status {
        case .excellent: String(localized: "You're in peak condition")
        case .good:      String(localized: "Your condition is good")
        case .fair:      String(localized: "You're at your usual level")
        case .tired:     String(localized: "Fatigue has been building up")
        case .warning:   String(localized: "Recovery is needed")
        }
    }
}
