#if DEBUG
import ActivityKit
import OSLog
import UIKit

/// Starts a real system Live Activity for a dedicated UI test launch.
@MainActor
enum WatchWorkoutActivityPreview {
    private static var didStart = false

    static func startIfRequested() async {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--uitesting"),
              let flagIndex = arguments.firstIndex(of: "--ui-watch-live-activity"),
              arguments.indices.contains(flagIndex + 1),
              let phase = PreviewPhase(rawValue: arguments[flagIndex + 1]),
              !didStart else { return }
        didStart = true

        // ActivityKit requires a foreground app for a local request. Give the
        // primary scene a bounded interval to finish becoming active.
        for _ in 0..<25 where UIApplication.shared.applicationState != .active {
            try? await Task.sleep(for: .milliseconds(200))
        }
        guard UIApplication.shared.applicationState == .active else { return }

        for activity in Activity<WatchWorkoutAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let now = Date()
        let exerciseName: String
        if let nameIndex = arguments.firstIndex(of: "--ui-watch-live-activity-name"),
           arguments.indices.contains(nameIndex + 1) {
            exerciseName = arguments[nameIndex + 1]
        } else {
            exerciseName = "Outdoor Run"
        }
        let activityType: WorkoutActivityType
        if let typeIndex = arguments.firstIndex(of: "--ui-watch-live-activity-type"),
           arguments.indices.contains(typeIndex + 1),
           let requestedType = WorkoutActivityType(rawValue: arguments[typeIndex + 1]) {
            activityType = requestedType
        } else {
            activityType = .running
        }
        let isStrength = activityType == .traditionalStrengthTraining
        let workoutKind: WatchWorkoutSnapshot.WorkoutKind = isStrength ? .strength : .cardio
        let selectedMetric = argument(after: "--ui-watch-live-activity-metric")
            .flatMap(WorkoutLiveActivityMetric.init(rawValue:)) ?? .elapsedTime
        let selectedStyle = argument(after: "--ui-watch-live-activity-style")
            .flatMap(WorkoutLiveActivityStyle.init(rawValue:)) ?? .goldImpact
        var preferences = WorkoutLiveActivityPreferences()
        if isStrength {
            preferences.strengthMetric = selectedMetric
        } else {
            preferences.cardioMetric = selectedMetric
        }
        preferences.style = selectedStyle
        preferences.save()

        // Explicit fixture values distinguish an actual zero from unavailable data.
        let isMissingWeight = arguments.contains("--ui-watch-live-activity-missing-weight")
        let supportsDistance = !arguments.contains("--ui-watch-live-activity-no-distance")
        let distanceMeters = arguments.contains("--ui-watch-live-activity-zero-distance") ? 0.0 : 1_200.0
        let currentSetWeightKg: Double? = isStrength && !isMissingWeight
            ? (arguments.contains("--ui-watch-live-activity-zero-weight") ? 0.0 : 60.0)
            : nil
        let snapshot = WatchWorkoutSnapshot(
            startedAt: now.addingTimeInterval(-73),
            updatedAt: now,
            exerciseName: exerciseName,
            elapsedSeconds: 73,
            phase: phase == .paused ? .paused : .running,
            heartRate: 142,
            activeCalories: 86,
            distanceMeters: distanceMeters,
            exerciseIconName: activityType.iconName,
            workoutKind: workoutKind,
            supportsDistance: supportsDistance,
            currentSetWeightKg: currentSetWeightKg
        )
        guard snapshot.isValid else { return }

        // Seed already-outdated content instead of relying on a scheduled system refresh.
        let staleDate = phase == .stale ? now.addingTimeInterval(-60) : now.addingTimeInterval(300)
        do {
            _ = try Activity.request(
                attributes: WatchWorkoutAttributes(mirrorID: UUID()),
                content: ActivityContent(
                    state: WatchWorkoutAttributes.ContentState(snapshot: snapshot, preferences: preferences),
                    staleDate: staleDate
                ),
                pushType: nil
            )
        } catch {
            AppLogger.ui.error("Unable to seed Watch workout activity: \(error.localizedDescription, privacy: .private)")
        }
    }

    private enum PreviewPhase: String {
        case running, paused, stale
    }

    private static func argument(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}
#endif
