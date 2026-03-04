import SwiftUI

/// Semicircular gauge showing cumulative sleep deficit over the last 7 days.
struct SleepDeficitGaugeView: View {
    let analysis: SleepDeficitAnalysis

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedProgress: Double = 0

    // Max deficit for gauge scale (10 hours in minutes)
    private let maxDeficitMinutes = 600.0

    private var progress: Double {
        min(analysis.weeklyDeficit / maxDeficitMinutes, 1.0)
    }

    var body: some View {
        StandardCard {
            VStack(spacing: DS.Spacing.lg) {
                Text("Sleep Debt")
                    .font(.callout)
                    .foregroundStyle(DS.Color.textSecondary)

                ZStack {
                    // Background arc
                    SemiCircleArc()
                        .stroke(
                            levelColor.opacity(DS.Opacity.border),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )

                    // Filled arc
                    SemiCircleArc()
                        .trim(from: 0, to: animatedProgress)
                        .stroke(
                            levelColor,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )

                    // Center label
                    VStack(spacing: DS.Spacing.xxs) {
                        Text(deficitText)
                            .font(.title2.bold())
                            .contentTransition(.numericText())

                        Text(levelLabel)
                            .font(.caption)
                            .foregroundStyle(levelColor)
                    }
                    .offset(y: 8)
                }
                .frame(width: 160, height: 90)

                // Averages comparison
                averagesRow
            }
            .padding(.vertical, DS.Spacing.sm)
        }
        .task {
            if reduceMotion {
                animatedProgress = progress
            } else {
                withAnimation(DS.Animation.slow) {
                    animatedProgress = progress
                }
            }
        }
        .onChange(of: analysis.weeklyDeficit) { _, _ in
            if reduceMotion {
                animatedProgress = progress
            } else {
                withAnimation(DS.Animation.emphasize) {
                    animatedProgress = progress
                }
            }
        }
    }

    // MARK: - Subviews

    private var averagesRow: some View {
        HStack(spacing: DS.Spacing.xl) {
            averageItem(
                label: String(localized: "14d avg"),
                minutes: analysis.shortTermAverage
            )
            if let longTerm = analysis.longTermAverage {
                Divider().frame(height: 32)
                averageItem(
                    label: String(localized: "90d avg"),
                    minutes: longTerm
                )
            }
        }
    }

    private func averageItem(label: String, minutes: Double) -> some View {
        VStack(spacing: DS.Spacing.xxs) {
            Text(formatHoursMinutes(minutes))
                .font(.subheadline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    // MARK: - Computed

    private var deficitText: String {
        formatHoursMinutes(analysis.weeklyDeficit)
    }

    private var levelColor: Color {
        switch analysis.level {
        case .good: DS.Color.scoreGood
        case .mild: DS.Color.scoreFair
        case .moderate: DS.Color.scoreTired
        case .severe: DS.Color.scoreWarning
        case .insufficient: DS.Color.textTertiary
        }
    }

    private var levelLabel: String {
        switch analysis.level {
        case .good: String(localized: "Well Rested")
        case .mild: String(localized: "Slightly Short")
        case .moderate: String(localized: "Sleep Debt")
        case .severe: String(localized: "Severe Debt")
        case .insufficient: String(localized: "Collecting Data")
        }
    }

    private func formatHoursMinutes(_ totalMinutes: Double) -> String {
        let hours = Int(totalMinutes) / 60
        let mins = Int(totalMinutes) % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}

// MARK: - Semicircle Arc Shape

private struct SemiCircleArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        let radius = min(rect.width / 2, rect.height)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        return path
    }
}
