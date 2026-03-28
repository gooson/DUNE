import Charts
import SwiftUI

struct SleepEnvironmentCard: View {
    let analysis: SleepEnvironmentAnalysis?

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    Label(String(localized: "Sleep Environment"), systemImage: "thermometer.medium")
                        .font(.callout)
                        .foregroundStyle(DS.Color.textSecondary)
                    Spacer()
                    if let analysis {
                        confidenceBadge(analysis.confidence)
                    }
                }

                if let analysis {
                    if let tempInsight = analysis.temperatureInsight {
                        insightRow(
                            icon: "thermometer.low",
                            message: tempInsight.message,
                            scoreDelta: tempInsight.bestSleepAvgScore - tempInsight.worstSleepAvgScore
                        )
                    }

                    if let humidityInsight = analysis.humidityInsight {
                        insightRow(
                            icon: "humidity",
                            message: humidityInsight.message,
                            scoreDelta: humidityInsight.bestSleepAvgScore - humidityInsight.worstSleepAvgScore
                        )
                    }

                    if !analysis.dailyPairs.isEmpty {
                        scatterChart(pairs: analysis.dailyPairs)
                            .frame(height: 100)
                            .clipped()
                    }
                } else {
                    SleepDataPlaceholder()
                }
            }
        }
        .accessibilityIdentifier("sleep-environment-card")
    }

    private func insightRow(icon: String, message: String, scoreDelta: Double) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(DS.Color.sleep)
                .frame(width: 20)
            Text(message)
                .font(.caption)
            Spacer()
            if scoreDelta > 1 {
                Text("+\(Int(scoreDelta))pt")
                    .font(.caption.bold())
                    .foregroundStyle(DS.Color.sleep)
            }
        }
    }

    private func scatterChart(pairs: [SleepEnvironmentAnalysis.DayPair]) -> some View {
        Chart(pairs) { pair in
            PointMark(
                x: .value("Temp", pair.temperature),
                y: .value("Score", pair.sleepScore)
            )
            .foregroundStyle(DS.Color.sleep.opacity(0.6))
            .symbolSize(15)
        }
        .chartXAxisLabel(String(localized: "Temperature (°C)"))
        .chartYAxisLabel(String(localized: "Sleep Score"))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) {
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                AxisValueLabel()
                    .font(.caption2)
            }
        }
    }

    private func confidenceBadge(_ confidence: SleepEnvironmentAnalysis.Confidence) -> some View {
        Text(confidence.displayName)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, DS.Spacing.xs)
            .padding(.vertical, 2)
            .background(badgeColor(confidence).opacity(DS.Opacity.light), in: Capsule())
            .foregroundStyle(badgeColor(confidence))
    }

    private func badgeColor(_ confidence: SleepEnvironmentAnalysis.Confidence) -> Color {
        switch confidence {
        case .low: .gray
        case .medium: .orange
        case .high: DS.Color.sleep
        }
    }
}
