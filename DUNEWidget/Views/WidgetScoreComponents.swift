import SwiftUI

struct WidgetMetric: Identifiable {
    let id: String
    let title: String
    let compactTitle: String
    let score: Int?
    let statusLabel: String
    let message: String?
    let color: Color
    let icon: String

    var progress: Double {
        Double(Swift.max(0, Swift.min(score ?? 0, 100))) / 100.0
    }

    var scoreText: String {
        score.map { "\($0)" } ?? "--"
    }

    var tintColor: Color {
        hasScore ? color : WidgetDS.Color.textTertiary
    }

    var secondaryText: String {
        hasScore ? statusLabel : WidgetMetricText.openDune
    }

    var detailText: String {
        guard hasScore else { return WidgetMetricText.openDune }
        guard let message, !message.isEmpty else { return statusLabel }
        return message
    }

    var hasScore: Bool {
        score != nil
    }
}

enum WidgetMetricText {
    static let condition = String(localized: "Condition")
    static let readiness = String(localized: "Readiness")
    static let wellness = String(localized: "Wellness")
    static let openDune = String(localized: "Open DUNE")
    static let today = String(localized: "Today")
}

extension WellnessDashboardEntry {
    var metrics: [WidgetMetric] {
        [
            WidgetMetric(
                id: "condition",
                title: WidgetMetricText.condition,
                compactTitle: "C",
                score: conditionScore,
                statusLabel: WidgetDS.labelForConditionStatus(conditionStatusRaw),
                message: conditionMessage,
                color: WidgetDS.colorForConditionStatus(conditionStatusRaw),
                icon: WidgetDS.iconForConditionStatus(conditionStatusRaw)
            ),
            WidgetMetric(
                id: "readiness",
                title: WidgetMetricText.readiness,
                compactTitle: "R",
                score: readinessScore,
                statusLabel: WidgetDS.labelForReadinessStatus(readinessStatusRaw),
                message: readinessMessage,
                color: WidgetDS.colorForReadinessStatus(readinessStatusRaw),
                icon: WidgetDS.iconForReadinessStatus(readinessStatusRaw)
            ),
            WidgetMetric(
                id: "wellness",
                title: WidgetMetricText.wellness,
                compactTitle: "W",
                score: wellnessScore,
                statusLabel: WidgetDS.labelForWellnessStatus(wellnessStatusRaw),
                message: wellnessMessage,
                color: WidgetDS.colorForWellnessStatus(wellnessStatusRaw),
                icon: WidgetDS.iconForWellnessStatus(wellnessStatusRaw)
            )
        ]
    }

    var lowestMetric: WidgetMetric? {
        metrics
            .filter(\.hasScore)
            .min { lhs, rhs in
                (lhs.score ?? 0) < (rhs.score ?? 0)
            }
    }
}

struct WidgetRingView: View {
    let metric: WidgetMetric
    let size: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(WidgetDS.Color.ringTrack, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            Circle()
                .trim(from: 0, to: metric.progress)
                .stroke(
                    AngularGradient(
                        colors: WidgetDS.ringGradient(for: metric.tintColor),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text(metric.scoreText)
                .font(.system(size: size * 0.31, weight: .bold, design: .rounded))
                .foregroundStyle(metric.tintColor)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(metric.title) \(metric.scoreText) \(metric.secondaryText)")
    }
}

struct WidgetCompactMetricView: View {
    let metric: WidgetMetric

    var body: some View {
        VStack(spacing: 5) {
            WidgetRingView(metric: metric, size: 34, lineWidth: 4.5)

            Text(metric.compactTitle)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(WidgetDS.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WidgetMetricTileView: View {
    let metric: WidgetMetric

    var body: some View {
        VStack(spacing: 7) {
            Text(metric.title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(WidgetDS.Color.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            WidgetRingView(metric: metric, size: 48, lineWidth: 5.5)

            if metric.hasScore {
                HStack(spacing: 3) {
                    Image(systemName: metric.icon)
                        .font(.system(size: 10, weight: .semibold))
                    Text(metric.statusLabel)
                        .lineLimit(1)
                }
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(metric.tintColor)
                .minimumScaleFactor(0.75)
            } else {
                Text(metric.secondaryText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(metric.tintColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

struct WidgetMetricRowView: View {
    let metric: WidgetMetric

    var body: some View {
        HStack(spacing: 12) {
            WidgetRingView(metric: metric, size: 38, lineWidth: 5)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(metric.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(WidgetDS.Color.textSecondary)

                    if metric.hasScore {
                        HStack(spacing: 3) {
                            Image(systemName: metric.icon)
                                .font(.system(size: 10, weight: .semibold))
                            Text(metric.statusLabel)
                                .lineLimit(1)
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(metric.tintColor)
                    } else {
                        Text(metric.secondaryText)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(metric.tintColor)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }

                Text(metric.detailText)
                    .font(.caption2)
                    .foregroundStyle(WidgetDS.Color.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(backgroundShape)
    }

    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: WidgetDS.Layout.rowCornerRadius, style: .continuous)
            .fill(metric.hasScore ? metric.tintColor.opacity(0.10) : WidgetDS.Color.placeholderFill)
            .overlay {
                RoundedRectangle(cornerRadius: WidgetDS.Layout.rowCornerRadius, style: .continuous)
                    .stroke(metric.hasScore ? metric.tintColor.opacity(0.18) : WidgetDS.Color.cardStroke, lineWidth: 1)
            }
    }
}
