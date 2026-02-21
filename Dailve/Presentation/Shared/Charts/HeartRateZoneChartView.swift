import SwiftUI
import Charts

/// Horizontal bar chart showing time distribution across 5 heart rate zones.
struct HeartRateZoneChartView: View {
    let zones: [HeartRateZone]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Heart Rate Zones")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Chart(zones) { zone in
                BarMark(
                    x: .value("Time", zone.durationSeconds / 60.0),
                    y: .value("Zone", zone.zone.displayName)
                )
                .foregroundStyle(zone.zone.color)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let mins = value.as(Double.self) {
                            Text(formatMinutes(mins))
                                .font(.caption2)
                        }
                    }
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.caption)
                        }
                    }
                }
            }
            .frame(height: 180)
            .clipped()

            // Zone legend with percentage
            HStack(spacing: DS.Spacing.md) {
                ForEach(zones) { zone in
                    if zone.percentage > 0 {
                        HStack(spacing: DS.Spacing.xs) {
                            Circle()
                                .fill(zone.zone.color)
                                .frame(width: 8, height: 8)
                            Text("\(Int(zone.percentage * 100))%")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(DS.Spacing.lg)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .fill(.thinMaterial)
        }
    }

    private func formatMinutes(_ mins: Double) -> String {
        if mins < 1 {
            return "\(Int(mins * 60))s"
        }
        return "\(Int(mins))m"
    }
}

// MARK: - HeartRateZone.Zone View Extension

extension HeartRateZone.Zone {
    var displayName: String {
        switch self {
        case .zone1: "Recovery"
        case .zone2: "Fat Burn"
        case .zone3: "Cardio"
        case .zone4: "Hard"
        case .zone5: "Peak"
        }
    }

    var color: Color {
        switch self {
        case .zone1: DS.Color.zone1
        case .zone2: DS.Color.zone2
        case .zone3: DS.Color.zone3
        case .zone4: DS.Color.zone4
        case .zone5: DS.Color.zone5
        }
    }
}
