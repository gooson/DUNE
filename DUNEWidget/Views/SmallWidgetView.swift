import SwiftUI

struct SmallWidgetView: View {
    let entry: WellnessDashboardEntry

    private enum Labels {
        static let condition = String(localized: "C")
        static let readiness = String(localized: "R")
        static let wellness  = String(localized: "W")
    }

    var body: some View {
        if entry.hasAnyScore {
            VStack(alignment: .leading, spacing: 6) {
                Text("DUNE")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(WidgetDS.Color.textSecondary)

                VStack(alignment: .leading, spacing: 4) {
                    if let score = entry.conditionScore {
                        scoreRow(label: Labels.condition, score: score, color: WidgetDS.colorForConditionStatus(entry.conditionStatusRaw))
                    }
                    if let score = entry.readinessScore {
                        scoreRow(label: Labels.readiness, score: score, color: WidgetDS.colorForReadinessStatus(entry.readinessStatusRaw))
                    }
                    if let score = entry.wellnessScore {
                        scoreRow(label: Labels.wellness, score: score, color: WidgetDS.colorForWellnessStatus(entry.wellnessStatusRaw))
                    }
                }

                Spacer(minLength: 0)

                if let statusRaw = entry.worstStatusRaw {
                    Text(WidgetDS.labelForConditionStatus(statusRaw))
                        .font(.caption2)
                        .foregroundStyle(WidgetDS.colorForConditionStatus(statusRaw))
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
        } else {
            placeholderView
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }

    private func scoreRow(label: String, score: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(WidgetDS.Color.textSecondary)
                .frame(width: 14, alignment: .leading)
            Text("\(score)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
                .monospacedDigit()
        }
    }

    private var placeholderView: some View {
        WidgetPlaceholderView(message: "Open DUNE", iconFont: .title2)
    }
}
