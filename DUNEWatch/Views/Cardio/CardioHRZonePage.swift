import SwiftUI

/// Page 2: Heart rate zone display — current HR, zone bar, zone name, avg HR.
struct CardioHRZonePage: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.appTheme) private var theme

    var body: some View {
        TimelineView(.periodic(from: .now, by: isLuminanceReduced ? 10 : 1)) { _ in
            VStack(spacing: DS.Spacing.md) {

                // Current HR (large, zone-colored)
                heartRateDisplay

                // Zone bar
                HRZoneBar(
                    currentZone: workoutManager.currentZone,
                    fraction: workoutManager.hrFraction
                )
                .padding(.horizontal, DS.Spacing.sm)

                // Zone name
                zoneLabel

                // Avg HR
                avgHeartRateRow
            }
            .padding(.horizontal, DS.Spacing.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Heart Rate Display

    private var heartRateDisplay: some View {
        VStack(spacing: DS.Spacing.xxs) {
            Image(systemName: "heart.fill")
                .font(.body)
                .foregroundStyle(zoneColor)

            Text(workoutManager.heartRate > 0
                ? "\(Int(workoutManager.heartRate))"
                : "--"
            )
            .font(DS.Typography.primaryMetric)
            .foregroundStyle(zoneColor)
            .contentTransition(.numericText())
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            Text("bpm")
                .font(DS.Typography.metricLabel)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Zone Label

    private var zoneLabel: some View {
        Group {
            if let zone = workoutManager.currentZone {
                HStack(spacing: DS.Spacing.xs) {
                    Text("Zone \(zone.rawValue)")
                        .font(DS.Typography.secondaryMetric)
                        .foregroundStyle(zone.color)

                    Text(zone.displayName)
                        .font(DS.Typography.metricLabel)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("--")
                    .font(DS.Typography.secondaryMetric)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Avg HR Row

    private var avgHeartRateRow: some View {
        HStack {
            Text("Avg HR")
                .font(DS.Typography.metricLabel)
                .foregroundStyle(.secondary)

            Spacer()

            Text(workoutManager.averageHeartRate > 0
                ? "\(Int(workoutManager.averageHeartRate)) bpm"
                : "-- bpm"
            )
            .font(DS.Typography.tileSubtitle.monospacedDigit())
            .foregroundStyle(.secondary)
            .contentTransition(.numericText())
        }
        .padding(.horizontal, DS.Spacing.xs)
        .frame(minHeight: 44)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Helpers

    private var zoneColor: Color {
        workoutManager.currentZone?.color ?? theme.metricHeartRate
    }
}
