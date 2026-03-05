import SwiftUI
import WidgetKit

struct LargeWidgetView: View {
    let entry: WellnessDashboardEntry

    var body: some View {
        if entry.hasAnyScore {
            VStack(alignment: .leading, spacing: 8) {
                headerRow

                VStack(spacing: 6) {
                    if let score = entry.conditionScore {
                        scoreRow(
                            title: String(localized: "Condition"),
                            score: score,
                            statusLabel: WidgetDS.labelForConditionStatus(entry.conditionStatusRaw),
                            message: entry.conditionMessage,
                            color: WidgetDS.colorForConditionStatus(entry.conditionStatusRaw),
                            icon: WidgetDS.iconForConditionStatus(entry.conditionStatusRaw)
                        )
                    }
                    if let score = entry.readinessScore {
                        scoreRow(
                            title: String(localized: "Readiness"),
                            score: score,
                            statusLabel: WidgetDS.labelForReadinessStatus(entry.readinessStatusRaw),
                            message: entry.readinessMessage,
                            color: WidgetDS.colorForReadinessStatus(entry.readinessStatusRaw),
                            icon: WidgetDS.iconForReadinessStatus(entry.readinessStatusRaw)
                        )
                    }
                    if let score = entry.wellnessScore {
                        scoreRow(
                            title: String(localized: "Wellness"),
                            score: score,
                            statusLabel: WidgetDS.labelForWellnessStatus(entry.wellnessStatusRaw),
                            message: entry.wellnessMessage,
                            color: WidgetDS.colorForWellnessStatus(entry.wellnessStatusRaw),
                            icon: WidgetDS.iconForWellnessStatus(entry.wellnessStatusRaw)
                        )
                    }
                }

                Spacer(minLength: 0)

                updatedAtRow
            }
            .containerBackground(.fill.tertiary, for: .widget)
        } else {
            placeholderView
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }

    private var headerRow: some View {
        HStack {
            Text("DUNE")
                .font(.headline)
                .fontWeight(.bold)
            Spacer()
            Text("Today")
                .font(.caption)
                .foregroundStyle(WidgetDS.Color.textSecondary)
        }
    }

    private func scoreRow(title: String, score: Int, statusLabel: String, message: String?, color: Color, icon: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(WidgetDS.Color.textSecondary)

                if let message {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(WidgetDS.Color.textTertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                Text("\(score)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
                    .monospacedDigit()

                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private var updatedAtRow: some View {
        HStack {
            Spacer()
            Text("Updated \(entry.date.formatted(date: .omitted, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(WidgetDS.Color.textTertiary)
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.text.clipboard")
                .font(.largeTitle)
                .foregroundStyle(WidgetDS.Color.textTertiary)
            Text("Open DUNE to see your health scores")
                .font(.callout)
                .foregroundStyle(WidgetDS.Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
