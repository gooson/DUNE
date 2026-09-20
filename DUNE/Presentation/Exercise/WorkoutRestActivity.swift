import ActivityKit
import Foundation
import OSLog

/// Owns the activity for one session; disabled activities never interrupt recording.
@MainActor
final class WorkoutRestActivity {
    private var activityID: String?
    // Shared across owners so a recreated view cannot adopt an activity being dismissed.
    private static var endingIDs = Set<String>()

    func start(sessionStartedAt: Date, exerciseName: String, setNumber: Int, endDate: Date, totalDuration: Int) {
        if let existing = Activity<WorkoutRestAttributes>.activities.first(where: {
            $0.attributes.sessionStartedAt == sessionStartedAt && $0.attributes.setNumber == setNumber
                && !Self.endingIDs.contains($0.id)
                && ($0.activityState == .active || $0.activityState == .stale)
        }) {
            activityID = existing.id
            update(endDate: endDate, totalDuration: totalDuration)
            return
        }
        end(sessionStartedAt: sessionStartedAt)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = WorkoutRestAttributes.ContentState(endDate: endDate, totalDuration: totalDuration)
        do {
            let activity = try Activity.request(
                attributes: WorkoutRestAttributes(sessionStartedAt: sessionStartedAt, exerciseName: exerciseName, setNumber: setNumber),
                content: ActivityContent(state: state, staleDate: endDate),
                pushType: nil
            )
            activityID = activity.id
        } catch {
            AppLogger.ui.error("Unable to start rest activity: \(error.localizedDescription)")
        }
    }

    func update(endDate: Date, totalDuration: Int) {
        guard let activityID else { return }
        let content = ActivityContent(
            state: WorkoutRestAttributes.ContentState(endDate: endDate, totalDuration: totalDuration),
            staleDate: endDate
        )
        Task { await Self.updateActivity(id: activityID, content: content) }
    }

    func end(sessionStartedAt: Date? = nil) {
        var ids = Set(Activity<WorkoutRestAttributes>.activities.filter {
            sessionStartedAt != nil && $0.attributes.sessionStartedAt == sessionStartedAt
        }.map(\.id))
        if let activityID { ids.insert(activityID) }
        activityID = nil
        for id in ids where Self.endingIDs.insert(id).inserted {
            Task {
                await Self.endActivity(id: id)
                Self.endingIDs.remove(id)
            }
        }
    }

    // Resolve ActivityKit handles inside the async operation; never transfer a retained
    // non-Sendable framework handle across actor isolation boundaries.
    nonisolated private static func updateActivity(
        id: String, content: ActivityContent<WorkoutRestAttributes.ContentState>
    ) async {
        guard let activity = Activity<WorkoutRestAttributes>.activities.first(where: { $0.id == id }) else { return }
        await activity.update(content)
    }

    nonisolated private static func endActivity(id: String) async {
        guard let activity = Activity<WorkoutRestAttributes>.activities.first(where: { $0.id == id }) else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
    }
}
