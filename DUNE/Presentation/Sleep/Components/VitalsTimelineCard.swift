import Charts
import SwiftUI

struct VitalsTimelineCard: View {
    let analysis: VitalsTimelineAnalysis?

    @State private var selectedTrack: VitalsTimelineAnalysis.VitalType = .heartRate

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Label(String(localized: "30-Day Vitals"), systemImage: "heart.text.clipboard")
                    .font(.callout)
                    .foregroundStyle(DS.Color.textSecondary)

                if let analysis {
                    trackPicker

                    if let track = trackFor(selectedTrack, in: analysis), track.hasData {
                        trackChart(track: track, type: selectedTrack)
                            .padding(.top, 16)
                            .frame(height: 136)
                            .clipped()

                        if let baseline = track.baseline {
                            HStack {
                                Text(String(localized: "Baseline: \(String(format: "%.1f", baseline)) \(selectedTrack.unit)"))
                                    .font(.caption)
                                    .foregroundStyle(DS.Color.textSecondary)
                                Spacer()
                                if !analysis.anomalyDays.isEmpty {
                                    Text(String(localized: "\(analysis.anomalyDays.count) anomaly days"))
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    } else {
                        Text(String(localized: "No data available for this vital"))
                            .font(.subheadline)
                            .foregroundStyle(DS.Color.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 152, alignment: .leading)
                    }
                } else {
                    SleepDataPlaceholder()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("sleep-vitals-timeline-card")
    }

    private var trackPicker: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(VitalsTimelineAnalysis.VitalType.allCases, id: \.self) { type in
                Button {
                    selectedTrack = type
                } label: {
                    Text(type.displayName)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, 4)
                        .background(
                            selectedTrack == type
                                ? DS.Color.sleep.opacity(DS.Opacity.light)
                                : Color.clear,
                            in: Capsule()
                        )
                        .foregroundStyle(selectedTrack == type ? DS.Color.sleep : DS.Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func trackChart(track: VitalsTimelineAnalysis.VitalTrack, type: VitalsTimelineAnalysis.VitalType) -> some View {
        Chart {
            ForEach(track.dailySummaries) { summary in
                AreaMark(
                    x: .value("Date", summary.date),
                    yStart: .value("Min", summary.min),
                    yEnd: .value("Max", summary.max)
                )
                .foregroundStyle(DS.Color.sleep.opacity(0.15))

                LineMark(
                    x: .value("Date", summary.date),
                    y: .value("Avg", summary.avg)
                )
                .foregroundStyle(DS.Color.sleep)
                .lineStyle(StrokeStyle(lineWidth: 1.5))

                if summary.isAnomaly {
                    PointMark(
                        x: .value("Date", summary.date),
                        y: .value("Avg", summary.avg)
                    )
                    .foregroundStyle(.red)
                    .symbolSize(20)
                }
            }

            if let baseline = track.baseline {
                RuleMark(y: .value("Baseline", baseline))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(DS.Color.textSecondary.opacity(0.5))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                    .foregroundStyle(Color.secondary.opacity(0.3))
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                    .foregroundStyle(Color.secondary.opacity(0.3))
                AxisValueLabel(format: .dateTime.day())
                    .font(.caption2)
            }
        }
    }

    private func trackFor(_ type: VitalsTimelineAnalysis.VitalType, in analysis: VitalsTimelineAnalysis) -> VitalsTimelineAnalysis.VitalTrack? {
        switch type {
        case .heartRate: analysis.heartRate
        case .respiratoryRate: analysis.respiratoryRate
        case .wristTemperature: analysis.wristTemperature
        case .spO2: analysis.spO2
        }
    }
}
