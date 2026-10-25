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
        let snapshot = WatchWorkoutSnapshot(
            startedAt: now.addingTimeInterval(-73),
            updatedAt: now,
            exerciseName: exerciseName,
            elapsedSeconds: 73,
            phase: phase == .paused ? .paused : .running,
            heartRate: 142,
            activeCalories: 86,
            distanceMeters: 1_200
        )
        guard snapshot.isValid else { return }

        // Seed already-outdated content instead of relying on a scheduled system refresh.
        let staleDate = phase == .stale ? now.addingTimeInterval(-60) : now.addingTimeInterval(300)
        do {
            _ = try Activity.request(
                attributes: WatchWorkoutAttributes(mirrorID: UUID()),
                content: ActivityContent(state: snapshot, staleDate: staleDate),
                pushType: nil
            )
        } catch {
            AppLogger.ui.error("Unable to seed Watch workout activity: \(error.localizedDescription, privacy: .private)")
        }
    }

    private enum PreviewPhase: String {
        case running, paused, stale
    }
}
#endif
