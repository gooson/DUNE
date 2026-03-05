import SwiftUI

struct MediumWidgetView: View {
    let entry: WellnessDashboardEntry

    private enum Labels {
        static let condition = String(localized: "Condition")
        static let readiness = String(localized: "Readiness")
        static let wellness  = String(localized: "Wellness")
    }

    var body: some View {
        if entry.hasAnyScore {
            HStack(spacing: 0) {
                if let score = entry.conditionScore {
                    scoreColumn(
                        title: Labels.condition,
                        score: score,
                        statusLabel: WidgetDS.labelForConditionStatus(entry.conditionStatusRaw),
                        color: WidgetDS.colorForConditionStatus(entry.conditionStatusRaw),
                        icon: WidgetDS.iconForConditionStatus(entry.conditionStatusRaw)
                    )
                }
                if let score = entry.readinessScore {
                    scoreColumn(
                        title: Labels.readiness,
                        score: score,
                        statusLabel: WidgetDS.labelForReadinessStatus(entry.readinessStatusRaw),
                        color: WidgetDS.colorForReadinessStatus(entry.readinessStatusRaw),
                        icon: WidgetDS.iconForReadinessStatus(entry.readinessStatusRaw)
                    )
                }
                if let score = entry.wellnessScore {
                    scoreColumn(
                        title: Labels.wellness,
                        score: score,
                        statusLabel: WidgetDS.labelForWellnessStatus(entry.wellnessStatusRaw),
                        color: WidgetDS.colorForWellnessStatus(entry.wellnessStatusRaw),
                        icon: WidgetDS.iconForWellnessStatus(entry.wellnessStatusRaw)
                    )
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
        } else {
            placeholderView
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }

    private func scoreColumn(title: String, score: Int, statusLabel: String, color: Color, icon: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(WidgetDS.Color.textSecondary)

            Text("\(score)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(color)
                .monospacedDigit()

            HStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(statusLabel)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundStyle(color)

            dotIndicator(score: score, color: color)
        }
        .frame(maxWidth: .infinity)
    }

    private func dotIndicator(score: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(index < filledDots(for: score) ? color : color.opacity(0.2))
                    .frame(width: 5, height: 5)
            }
        }
    }

    private func filledDots(for score: Int) -> Int {
        switch score {
        case 80...100: 5
        case 60..<80:  4
        case 40..<60:  3
        case 20..<40:  2
        default:       1
        }
    }

    private var placeholderView: some View {
        WidgetPlaceholderView(message: "Open DUNE to see your scores", iconFont: .title2)
    }
}
