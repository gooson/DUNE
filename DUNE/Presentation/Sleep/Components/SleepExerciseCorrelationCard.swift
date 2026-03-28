import SwiftUI
import Charts

struct SleepExerciseCorrelationCard: View {
    let correlation: SleepExerciseCorrelation

    private var sortedBands: [(band: SleepExerciseCorrelation.IntensityBand, stats: SleepExerciseCorrelation.SleepStats)] {
        SleepExerciseCorrelation.IntensityBand.allCases.compactMap { band in
            guard let stats = correlation.intensityBreakdown[band] else { return nil }
            return (band, stats)
        }
    }

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    Label(String(localized: "Sleep & Exercise"), systemImage: "figure.run")
                        .font(.callout)
                        .foregroundStyle(DS.Color.textSecondary)
                    Spacer()
                    confidenceBadge
                }

                if !sortedBands.isEmpty {
                    Chart(sortedBands, id: \.band) { item in
                        BarMark(
                            x: .value("Band", item.band.displayName),
                            y: .value("Score", item.stats.avgScore)
                        )
                        .foregroundStyle(bandColor(item.band))
                        .annotation(position: .top) {
                            Text("\(Int(item.stats.avgScore))")
                                .font(.caption2)
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                    .chartYScale(domain: 0...110)
                    .chartYAxis {
                        AxisMarks(values: [0, 25, 50, 75, 100]) { _ in
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .frame(height: 150)
                    .clipped()
                }

                if let insight = correlation.overallInsight {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                        Text(insight)
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                }

                if correlation.confidence == .low {
                    Text(String(localized: "More data needed for accurate analysis"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .accessibilityIdentifier("sleep-exercise-correlation-card")
    }

    private var confidenceBadge: some View {
        let (text, color): (String, Color) = switch correlation.confidence {
        case .low: (String(localized: "Low"), .gray)
        case .medium: (String(localized: "Medium"), .orange)
        case .high: (String(localized: "High"), .green)
        }
        return Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, DS.Spacing.xs)
            .padding(.vertical, 2)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
    }

    private func bandColor(_ band: SleepExerciseCorrelation.IntensityBand) -> Color {
        switch band {
        case .rest: .gray
        case .light: .green
        case .moderate: DS.Color.activity
        case .intense: .red
        }
    }
}
