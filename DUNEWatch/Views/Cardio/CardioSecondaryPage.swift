import SwiftUI

/// Page 3: Activity-specific secondary metrics.
/// Running: Avg Pace + current Pace + Distance.
/// Cycling: Avg Speed + current Speed + Distance.
/// Swimming: Distance + Avg Pace per 100m.
/// Generic: Distance + Duration.
struct CardioSecondaryPage: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        TimelineView(.periodic(from: .now, by: isLuminanceReduced ? 10 : 1)) { context in
            VStack(spacing: DS.Spacing.md) {
                // Page title
                HStack {
                    Text(workoutManager.supportsMachineLevel ? "Level" : profile.secondaryPageTitle)
                        .font(DS.Typography.metricLabel)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                Spacer(minLength: 0)

                // Profile-specific content
                profileContent(now: context.date)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DS.Spacing.sm)
        }
    }

    // MARK: - Profile

    private var profile: CardioMetricProfile {
        guard case .cardio(let type, _) = workoutManager.workoutMode else {
            return .generic
        }
        return CardioMetricProfile.profile(for: type)
    }

    // MARK: - Profile Content

    @ViewBuilder
    private func profileContent(now: Date) -> some View {
        if workoutManager.supportsMachineLevel {
            machineLevelContent
        } else {
            switch profile {
            case .running:
                runningContent(now: now)
            case .cycling:
                cyclingContent(now: now)
            case .swimming:
                swimmingContent
            case .generic:
                genericContent(now: now)
            }
        }
    }

    private var machineLevelContent: some View {
        VStack(spacing: DS.Spacing.lg) {
            VStack(spacing: DS.Spacing.xxs) {
                Text(workoutManager.formattedCurrentMachineLevel)
                    .font(DS.Typography.primaryMetric)
                    .foregroundStyle(DS.Color.activity)
                    .contentTransition(.numericText())

                Text("Current")
                    .font(DS.Typography.metricLabel)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: DS.Spacing.lg) {
                Button {
                    workoutManager.adjustMachineLevel(by: -1)
                } label: {
                    Image(systemName: "minus")
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.bordered)

                Button {
                    workoutManager.adjustMachineLevel(by: 1)
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.Color.activity)
            }

            HStack(spacing: DS.Spacing.lg) {
                VStack(spacing: DS.Spacing.xxs) {
                    Text(workoutManager.formattedAverageMachineLevel)
                        .font(DS.Typography.secondaryMetric)
                        .contentTransition(.numericText())

                    Text("Avg Level")
                        .font(DS.Typography.metricLabel)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: DS.Spacing.xxs) {
                    Text(workoutManager.formattedMaxMachineLevel)
                        .font(DS.Typography.secondaryMetric)
                        .contentTransition(.numericText())

                    Text("Max Level")
                        .font(DS.Typography.metricLabel)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Running

    private func runningContent(now: Date) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            // Avg Pace (primary)
            VStack(spacing: DS.Spacing.xxs) {
                Text(avgPace(now: now))
                    .font(DS.Typography.primaryMetric)
                    .foregroundStyle(DS.Color.activity)
                    .contentTransition(.numericText())

                Text("Avg Pace")
                    .font(DS.Typography.metricLabel)
                    .foregroundStyle(.secondary)
            }

            // Current Pace + Distance
            HStack(spacing: DS.Spacing.lg) {
                VStack(spacing: DS.Spacing.xxs) {
                    Text(workoutManager.formattedPace)
                        .font(DS.Typography.secondaryMetric)
                        .contentTransition(.numericText())

                    Text("Pace")
                        .font(DS.Typography.metricLabel)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: DS.Spacing.xxs) {
                    Text(String(format: "%.2f", workoutManager.distanceKm))
                        .font(DS.Typography.secondaryMetric)
                        .contentTransition(.numericText())

                    Text("km")
                        .font(DS.Typography.metricLabel)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Cycling

    private func cyclingContent(now: Date) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            // Avg Speed (primary)
            VStack(spacing: DS.Spacing.xxs) {
                Text(avgSpeed(now: now))
                    .font(DS.Typography.primaryMetric)
                    .foregroundStyle(DS.Color.activity)
                    .contentTransition(.numericText())

                Text("Avg Speed")
                    .font(DS.Typography.metricLabel)
                    .foregroundStyle(.secondary)
            }

            // Current Speed + Distance
            HStack(spacing: DS.Spacing.lg) {
                VStack(spacing: DS.Spacing.xxs) {
                    Text(currentSpeed)
                        .font(DS.Typography.secondaryMetric)
                        .contentTransition(.numericText())

                    Text("km/h")
                        .font(DS.Typography.metricLabel)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: DS.Spacing.xxs) {
                    Text(String(format: "%.2f", workoutManager.distanceKm))
                        .font(DS.Typography.secondaryMetric)
                        .contentTransition(.numericText())

                    Text("km")
                        .font(DS.Typography.metricLabel)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Swimming

    private var swimmingContent: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Distance (primary)
            VStack(spacing: DS.Spacing.xxs) {
                Text(String(format: "%.0f", workoutManager.distance))
                    .font(DS.Typography.primaryMetric)
                    .foregroundStyle(DS.Color.activity)
                    .contentTransition(.numericText())

                Text("m")
                    .font(DS.Typography.metricLabel)
                    .foregroundStyle(.secondary)
            }

            // Avg Pace per 100m
            HStack {
                Text("Avg /100m")
                    .font(DS.Typography.metricLabel)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(avgPacePer100m)
                    .font(DS.Typography.secondaryMetric)
                    .contentTransition(.numericText())
            }
        }
    }

    // MARK: - Generic

    private func genericContent(now: Date) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            // Elapsed time (primary)
            VStack(spacing: DS.Spacing.xxs) {
                let elapsed = workoutManager.activeElapsedTime(at: now)
                let hours = Int(elapsed) / 3600
                let mins = (Int(elapsed) % 3600) / 60
                let secs = Int(elapsed) % 60

                Text(hours > 0
                    ? String(format: "%d:%02d:%02d", hours, mins, secs)
                    : String(format: "%d:%02d", mins, secs)
                )
                .font(DS.Typography.primaryMetric)
                .foregroundStyle(DS.Color.activity)
                .contentTransition(.numericText())

                Text("Elapsed")
                    .font(DS.Typography.metricLabel)
                    .foregroundStyle(.secondary)
            }

            // Distance + Calories
            HStack(spacing: DS.Spacing.lg) {
                VStack(spacing: DS.Spacing.xxs) {
                    Text(String(format: "%.2f", workoutManager.distanceKm))
                        .font(DS.Typography.secondaryMetric)
                        .contentTransition(.numericText())

                    Text("km")
                        .font(DS.Typography.metricLabel)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: DS.Spacing.xxs) {
                    Text(workoutManager.activeCalories > 0
                        ? "\(Int(workoutManager.activeCalories))"
                        : "--"
                    )
                    .font(DS.Typography.secondaryMetric)
                    .contentTransition(.numericText())

                    Text("kcal")
                        .font(DS.Typography.metricLabel)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Computed Helpers

    /// Average pace formatted as "M:SS" from distance / active elapsed.
    private func avgPace(now: Date) -> String {
        let elapsed = workoutManager.activeElapsedTime(at: now)
        let distKm = workoutManager.distanceKm
        guard distKm > 0.01, elapsed > 0 else { return "--:--" }
        let paceSeconds = elapsed / distKm
        guard paceSeconds.isFinite, paceSeconds < 3600 else { return "--:--" }
        let mins = Int(paceSeconds) / 60
        let secs = Int(paceSeconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    /// Average speed formatted as "XX.X" km/h from distance / active elapsed.
    private func avgSpeed(now: Date) -> String {
        let elapsed = workoutManager.activeElapsedTime(at: now)
        let distKm = workoutManager.distanceKm
        guard distKm > 0.01, elapsed > 0 else { return "--" }
        let speedKmh = distKm / (elapsed / 3600.0)
        guard speedKmh.isFinite else { return "--" }
        return String(format: "%.1f", speedKmh)
    }

    /// Current speed in km/h from current pace.
    private var currentSpeed: String {
        let pace = workoutManager.currentPace
        guard pace > 0, pace.isFinite, pace < 3600 else { return "--" }
        let speedKmh = 3600.0 / pace
        return String(format: "%.1f", speedKmh)
    }

    /// Average pace per 100m for swimming.
    private var avgPacePer100m: String {
        let elapsed = workoutManager.activeElapsedTime
        let dist = workoutManager.distance
        guard dist > 1, elapsed > 0 else { return "--:--" }
        let pacePer100m = (elapsed / dist) * 100.0
        guard pacePer100m.isFinite, pacePer100m < 3600 else { return "--:--" }
        let mins = Int(pacePer100m) / 60
        let secs = Int(pacePer100m) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
