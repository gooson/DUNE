import SwiftUI
import WatchKit

/// Page 1: Primary cardio metrics — elapsed time, distance/pace, HR, calories.
/// Layout adapts based on CardioMetricProfile (running shows pace, cycling shows speed).
struct CardioMainMetricsPage: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        TimelineView(.periodic(from: .now, by: isLuminanceReduced ? 10 : 1)) { context in
            ScrollView(.vertical) {
                VStack(spacing: DS.Spacing.md) {
                    // Activity type header
                    activityHeader

                    // Elapsed time (large)
                    elapsedTimeDisplay(now: context.date)

                    // Distance + Pace/Speed (medium 2-col)
                    if workoutManager.supportsMachineLevel {
                        currentLevelRow
                    } else if profile.showsDistance {
                        distanceRow
                    }

                    heartRateZone
                }
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.bottom, DS.Spacing.md)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .accessibilityIdentifier("watch-cardio-main-metrics")
    }

    // MARK: - Profile

    private var profile: CardioMetricProfile {
        guard case .cardio(let type, _) = workoutManager.workoutMode else {
            return .generic
        }
        return CardioMetricProfile.profile(for: type)
    }

    // MARK: - Activity Header

    private var activityHeader: some View {
        HStack(spacing: DS.Spacing.xxs) {
            if case .cardio(let type, _) = workoutManager.workoutMode {
                Image(systemName: type.iconName)
                    .font(.caption2)
                    .foregroundStyle(DS.Color.activity)

                Text(LocalizedStringKey(type.typeName))
                    .font(DS.Typography.metricLabel)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer()

            HStack(spacing: DS.Spacing.xxs) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(DS.Color.caution)
                    .accessibilityHidden(true)
                Text(workoutManager.activeCalories > 0
                    ? Int(workoutManager.activeCalories).formatted()
                    : "--")
                Text("kcal")
            }
            .font(DS.Typography.metricLabel)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Calories")
            .accessibilityValue(Text(verbatim: workoutManager.activeCalories > 0
                ? "\(Int(workoutManager.activeCalories)) kcal"
                : "-- kcal"))
            .accessibilityIdentifier("watch-cardio-calories-value")
        }
    }

    // MARK: - Elapsed Time

    private func elapsedTimeDisplay(now: Date) -> some View {
        let elapsed = workoutManager.activeElapsedTime(at: now)
        let hours = Int(elapsed) / 3600
        let mins = (Int(elapsed) % 3600) / 60
        let secs = Int(elapsed) % 60

        return Text(hours > 0
            ? String(format: "%d:%02d:%02d", hours, mins, secs)
            : String(format: "%d:%02d", mins, secs)
        )
        .font(DS.Typography.primaryMetric)
        .foregroundStyle(DS.Color.activity)
        .contentTransition(.numericText())
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("watch-cardio-elapsed-time")
    }

    // MARK: - Distance Row

    private var distanceRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Distance
            VStack(spacing: DS.Spacing.xxs) {
                Text(String(format: "%.2f", workoutManager.distanceKm))
                    .font(DS.Typography.secondaryMetric)
                    .contentTransition(.numericText())

                Text("km")
                    .font(DS.Typography.metricLabel)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))

            // Pace or Speed
            if profile.showsPace {
                VStack(spacing: DS.Spacing.xxs) {
                    Text(workoutManager.formattedPace)
                        .font(DS.Typography.secondaryMetric)
                        .contentTransition(.numericText())

                    Text("/km")
                        .font(DS.Typography.metricLabel)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            } else if profile.showsSpeed {
                VStack(spacing: DS.Spacing.xxs) {
                    Text(formattedSpeed)
                        .font(DS.Typography.secondaryMetric)
                        .contentTransition(.numericText())

                    Text("km/h")
                        .font(DS.Typography.metricLabel)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            }
        }
    }

    /// Current speed in km/h derived from pace (seconds/km).
    private var formattedSpeed: String {
        let pace = workoutManager.currentPace
        guard pace > 0, pace.isFinite, pace < 3600 else { return "--" }
        let speedKmh = 3600.0 / pace
        return String(format: "%.1f", speedKmh)
    }

    // MARK: - Machine Level

    private var currentLevelRow: some View {
        VStack(spacing: DS.Spacing.xxs) {
            Text(workoutManager.formattedCurrentMachineLevel)
                .font(DS.Typography.secondaryMetric)
                .foregroundStyle(DS.Color.activity)
                .contentTransition(.numericText())
                .accessibilityIdentifier("watch-cardio-machine-level")

            Text("Level")
                .font(DS.Typography.metricLabel)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Heart Rate Zone

    private var heartRateZone: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                Image(systemName: "heart.fill")
                    .font(DS.Typography.metricLabel)
                    .foregroundStyle(zoneColor)
                    .accessibilityHidden(true)

                Text(workoutManager.heartRate > 0
                    ? Int(workoutManager.heartRate).formatted()
                    : "--")
                    .font(DS.Typography.secondaryMetric)
                    .foregroundStyle(zoneColor)
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("watch-cardio-main-heart-rate-value")
                    .accessibilityLabel("Heart Rate")
                    .accessibilityValue(Text(verbatim: workoutManager.heartRate > 0
                        ? "\(Int(workoutManager.heartRate)) bpm"
                        : "-- bpm"))

                Text("bpm")
                    .font(DS.Typography.metricLabel)
                    .foregroundStyle(.secondary)

                Spacer(minLength: DS.Spacing.xs)

                Group {
                    if let index = workoutManager.displayedZoneIndex {
                        Text("Zone \(index)")
                    } else {
                        Text("Zone \("--")")
                    }
                }
                .font(DS.Typography.metricLabel.weight(.semibold))
                .foregroundStyle(zoneColor)
                .lineLimit(1)
                .accessibilityIdentifier("watch-cardio-main-heart-rate-zone-label")
            }

            HRZoneBar(
                activeIndex: workoutManager.displayedZoneIndex,
                zoneCount: workoutManager.displayedZoneCount
            )
            .accessibilityIdentifier("watch-cardio-main-heart-rate-zones")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var zoneColor: Color {
        workoutManager.displayedZoneIndex.map {
            HRZoneBar.color(for: $0, count: workoutManager.displayedZoneCount)
        } ?? .secondary
    }
}
