import SwiftUI
import Charts

struct NocturnalVitalsChartView: View {
    let snapshot: NocturnalVitalsSnapshot

    @State private var selectedTrack: VitalTrack = .heartRate

    enum VitalTrack: String, CaseIterable {
        case heartRate, respiratoryRate, temperature, spO2

        var displayName: String {
            switch self {
            case .heartRate: String(localized: "Heart Rate")
            case .respiratoryRate: String(localized: "Respiratory Rate")
            case .temperature: String(localized: "Wrist Temp")
            case .spO2: String(localized: "SpO2")
            }
        }

        var icon: String {
            switch self {
            case .heartRate: "heart.fill"
            case .respiratoryRate: "wind"
            case .temperature: "thermometer.medium"
            case .spO2: "lungs.fill"
            }
        }
    }

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Label(String(localized: "Overnight Vitals"), systemImage: "moon.stars.fill")
                    .font(.callout)
                    .foregroundStyle(DS.Color.textSecondary)

                trackPicker

                if !activeBuckets.isEmpty {
                    Chart(activeBuckets) { bucket in
                        LineMark(
                            x: .value("Time", bucket.id),
                            y: .value(selectedTrack.displayName, bucket.avg)
                        )
                        .foregroundStyle(trackColor)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Time", bucket.id),
                            yStart: .value("Min", bucket.min),
                            yEnd: .value("Max", bucket.max)
                        )
                        .foregroundStyle(trackColor.opacity(0.1))
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .hour)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.hour())
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(height: 160)
                    .clipped()
                } else {
                    Text(String(localized: "No data available for this metric"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(height: 100)
                        .frame(maxWidth: .infinity)
                }

                summaryGrid
            }
        }
        .accessibilityIdentifier("sleep-nocturnal-vitals-card")
        .task {
            if activeBuckets.isEmpty, let first = availableTracks.first {
                selectedTrack = first
            }
        }
    }

    private var trackPicker: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(availableTracks, id: \.self) { track in
                Button {
                    selectedTrack = track
                } label: {
                    Label(track.displayName, systemImage: track.icon)
                        .font(.caption2)
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, 4)
                        .background(
                            selectedTrack == track
                                ? trackColor.opacity(0.2)
                                : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(selectedTrack == track ? trackColor : .secondary)
            }
        }
    }

    private var summaryGrid: some View {
        let summary = snapshot.summary
        return HStack(spacing: DS.Spacing.md) {
            if let minHR = summary.minHeartRate {
                summaryItem(label: String(localized: "Min HR"), value: "\(Int(minHR))", unit: "bpm")
            }
            if let avgHR = summary.avgHeartRate {
                summaryItem(label: String(localized: "Avg HR"), value: "\(Int(avgHR))", unit: "bpm")
            }
            if let avgRR = summary.avgRespiratoryRate {
                summaryItem(label: String(localized: "Avg RR"), value: avgRR.formattedWithSeparator(fractionDigits: 1), unit: "br/min")
            }
            if let dev = summary.wristTempDeviation {
                summaryItem(label: String(localized: "Temp Δ"), value: dev.formattedWithSeparator(fractionDigits: 1, alwaysShowSign: true), unit: "°C")
            }
        }
    }

    private func summaryItem(label: String, value: String, unit: String) -> some View {
        VStack(spacing: DS.Spacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.callout.bold())
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var activeBuckets: [NocturnalVitalsSnapshot.VitalBucket] {
        switch selectedTrack {
        case .heartRate: snapshot.heartRateBuckets
        case .respiratoryRate: snapshot.respiratoryRateBuckets
        case .temperature: snapshot.wristTemperatureBuckets
        case .spO2: snapshot.spO2Buckets
        }
    }

    private var availableTracks: [VitalTrack] {
        VitalTrack.allCases.filter { track in
            switch track {
            case .heartRate: !snapshot.heartRateBuckets.isEmpty
            case .respiratoryRate: !snapshot.respiratoryRateBuckets.isEmpty
            case .temperature: !snapshot.wristTemperatureBuckets.isEmpty
            case .spO2: !snapshot.spO2Buckets.isEmpty
            }
        }
    }

    private var trackColor: Color {
        switch selectedTrack {
        case .heartRate: DS.Color.heartRate
        case .respiratoryRate, .temperature, .spO2: DS.Color.vitals
        }
    }
}
