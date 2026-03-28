import SwiftUI
import Charts

struct BreathingDisturbanceCard: View {
    let analysis: BreathingDisturbanceAnalysis

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    Label(String(localized: "Breathing Disturbances"), systemImage: "lungs")
                        .font(.callout)
                        .foregroundStyle(DS.Color.textSecondary)
                    Spacer()
                    riskBadge
                }

                if let average = analysis.average {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(average.formattedWithSeparator(fractionDigits: 1))
                            .font(.title2.bold())
                        Text(String(localized: "/hr avg"))
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                }

                if !analysis.samples.isEmpty {
                    Chart(analysis.samples.suffix(30), id: \.date) { sample in
                        BarMark(
                            x: .value("Date", sample.date, unit: .day),
                            y: .value("Disturbances", sample.value)
                        )
                        .foregroundStyle(sample.isElevated ? Color.red : DS.Color.sleep)
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(height: 120)
                    .clipped()
                }

                if analysis.elevatedNightCount > 0 {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(String(localized: "\(analysis.elevatedNightCount) elevated nights in 30 days"))
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                }
            }
        }
        .accessibilityIdentifier("sleep-breathing-disturbance-card")
    }

    private var riskBadge: some View {
        Text(analysis.riskLevel.displayName)
            .font(.caption2.bold())
            .padding(.horizontal, DS.Spacing.xs)
            .padding(.vertical, 2)
            .background(riskColor.opacity(0.2), in: Capsule())
            .foregroundStyle(riskColor)
    }

    private var riskColor: Color {
        switch analysis.riskLevel {
        case .normal: .green
        case .mild: .orange
        case .elevated, .significant: .red
        }
    }
}
