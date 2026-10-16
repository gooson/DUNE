import SwiftUI

/// Page 2: Heart rate zone display — current HR, zone bar, zone name, avg HR.
struct CardioHRZonePage: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.appTheme) private var theme

    var body: some View {
        TimelineView(.periodic(from: .now, by: isLuminanceReduced ? 10 : 1)) { _ in
            ScrollView(.vertical) {
                VStack(spacing: DS.Spacing.md) {

                    // Current HR (large, zone-colored)
                    heartRateDisplay

                    // Zone bar
                    HRZoneBar(
                        activeIndex: workoutManager.displayedZoneIndex,
                        zoneCount: workoutManager.displayedZoneCount
                    )
                    .padding(.horizontal, DS.Spacing.sm)

                    // Zone name
                    zoneLabel

                    // Avg HR
                    avgHeartRateRow
                }
                .padding(.horizontal, DS.Spacing.sm)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .accessibilityIdentifier("watch-cardio-hr-zone")
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
            if let index = workoutManager.displayedZoneIndex {
                HStack(spacing: DS.Spacing.xs) {
                    Text("Zone \(index)")
                        .font(DS.Typography.secondaryMetric)
                        .foregroundStyle(zoneColor)
                        .accessibilityIdentifier("watch-live-heart-rate-zone-label")

                    if workoutManager.liveZoneDistribution == nil,
                       let estimatedZone = workoutManager.currentZone {
                        Text(estimatedZone.displayName)
                            .font(DS.Typography.metricLabel)
                            .foregroundStyle(.secondary)
                    }
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
        guard let index = workoutManager.displayedZoneIndex else { return theme.metricHeartRate }
        return HRZoneBar.color(for: index, count: workoutManager.displayedZoneCount)
    }
}
