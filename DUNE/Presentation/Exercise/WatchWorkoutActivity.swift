import ActivityKit
import Foundation
import OSLog

@MainActor
protocol WatchWorkoutActivityDriving {
    func start(mirrorID: UUID, snapshot: WatchWorkoutSnapshot) throws -> String?
    func update(id: String, snapshot: WatchWorkoutSnapshot) async
    func end(id: String) async
}

/// Serializes ActivityKit operations so an in-flight update cannot revive an ended workout.
@MainActor
final class WatchWorkoutActivity {
    private let driver: any WatchWorkoutActivityDriving
    private var mirrorID: UUID?
    private(set) var snapshot: WatchWorkoutSnapshot?
    private struct Update {
        let mirrorID: UUID
        let snapshot: WatchWorkoutSnapshot
        var requestedID: String?
        var didRequest = false
    }
    private var pending: [Update] = []
    private var updateTask: Task<Void, Never>?
    private var activityID: String?
    private var activityMirrorID: UUID?
    private var attemptedMirrorID: UUID?
    private var acceptsInitialStartCorrection = false
    private static let maximumEndedSnapshots = 32
    private var endedSnapshotsByStart: [Date: WatchWorkoutSnapshot] = [:]

    init(driver: any WatchWorkoutActivityDriving = SystemWatchWorkoutActivityDriver()) {
        self.driver = driver
    }

    func start(mirrorID: UUID, snapshot: WatchWorkoutSnapshot, requestedID: String? = nil,
               didRequest: Bool = false, allowsStartCorrection: Bool = false) {
        guard snapshot.isValid, snapshot.phase != .ended else { return }
        self.mirrorID = mirrorID
        self.snapshot = snapshot
        acceptsInitialStartCorrection = allowsStartCorrection
        // An unidentified placeholder must not become a stranded system activity.
        if !allowsStartCorrection {
            enqueue(Update(mirrorID: mirrorID, snapshot: snapshot, requestedID: requestedID, didRequest: didRequest))
        }
        if let final = endedSnapshotsByStart[snapshot.startedAt] {
            finish(matching: final)
        }
    }

    func receive(_ incoming: WatchWorkoutSnapshot, mirrorID: UUID, authoritative: Bool = false) {
        guard self.mirrorID == mirrorID,
              let current = snapshot, current.phase != .ended,
              incoming.isValid,
              (abs(incoming.startedAt.timeIntervalSince(current.startedAt)) < 2
                || (acceptsInitialStartCorrection && authoritative)),
              (incoming.updatedAt >= current.updatedAt
                || (acceptsInitialStartCorrection && authoritative)) else { return }
        if acceptsInitialStartCorrection && !authoritative { return }
        if authoritative { acceptsInitialStartCorrection = false }
        snapshot = incoming
        enqueue(Update(mirrorID: mirrorID, snapshot: incoming))
        if let final = endedSnapshotsByStart[incoming.startedAt] {
            finish(matching: final)
        }
    }

    func finish(mirrorID: UUID, at date: Date = Date()) {
        guard self.mirrorID == mirrorID, var final = snapshot, final.phase != .ended else { return }
        final.elapsedSeconds = final.elapsed(at: date)
        final.updatedAt = max(date, final.updatedAt)
        final.phase = .ended
        snapshot = final
        enqueue(Update(mirrorID: mirrorID, snapshot: final))
    }

    /// A terminal Watch payload remains authoritative even if its mirror disconnected.
    @discardableResult
    func finish(matching final: WatchWorkoutSnapshot) -> Bool {
        guard final.isValid, final.phase == .ended else { return false }
        if endedSnapshotsByStart[final.startedAt].map({ final.updatedAt >= $0.updatedAt }) ?? true {
            endedSnapshotsByStart[final.startedAt] = final
        }
        if endedSnapshotsByStart.count > Self.maximumEndedSnapshots,
           let oldestStart = endedSnapshotsByStart.keys.min() {
            endedSnapshotsByStart.removeValue(forKey: oldestStart)
        }
        guard let mirrorID, let current = snapshot, current.isSameWorkout(as: final) else { return false }
        guard current.phase != .ended else { return true }
        snapshot = final
        acceptsInitialStartCorrection = false
        enqueue(Update(mirrorID: mirrorID, snapshot: final))
        return true
    }

    func waitForPendingUpdates() async { await updateTask?.value }

    private func enqueue(_ update: Update) {
        if let last = pending.last, last.mirrorID == update.mirrorID,
           !last.didRequest, !update.didRequest, last.snapshot.phase != .ended {
            pending[pending.count - 1] = update
        } else {
            pending.append(update)
        }
        guard updateTask == nil else { return }
        updateTask = Task { [weak self] in
            guard let self else { return }
            while !pending.isEmpty {
                let update = pending.removeFirst()
                let id = update.mirrorID
                let value = update.snapshot
                if activityMirrorID != id || value.phase == .ended {
                    if let activityID { await driver.end(id: activityID) }
                    activityID = nil
                    activityMirrorID = nil
                }
                guard value.phase != .ended else { continue }
                if update.didRequest {
                    attemptedMirrorID = id
                    activityID = update.requestedID
                    activityMirrorID = activityID == nil ? nil : id
                    continue
                }
                if let activityID {
                    await driver.update(id: activityID, snapshot: value)
                } else if attemptedMirrorID != id {
                    attemptedMirrorID = id
                    do {
                        activityID = try driver.start(mirrorID: id, snapshot: value)
                        activityMirrorID = activityID == nil ? nil : id
                    } catch {
                        AppLogger.ui.error("Unable to start Watch workout activity: \(error.localizedDescription, privacy: .private)")
                    }
                }
            }
            updateTask = nil
        }
    }
}

@MainActor
private struct SystemWatchWorkoutActivityDriver: WatchWorkoutActivityDriving {
    func start(mirrorID: UUID, snapshot: WatchWorkoutSnapshot) throws -> String? {
        try WatchWorkoutActivityRequest.start(mirrorID: mirrorID, snapshot: snapshot)
    }

    func update(id: String, snapshot: WatchWorkoutSnapshot) async {
        await Self.updateActivity(id: id, snapshot: snapshot)
    }

    func end(id: String) async { await Self.endActivity(id: id) }

    nonisolated private static func content(_ snapshot: WatchWorkoutSnapshot) -> ActivityContent<WatchWorkoutSnapshot> {
        ActivityContent(state: snapshot, staleDate: snapshot.updatedAt.addingTimeInterval(30))
    }

    nonisolated private static func updateActivity(id: String, snapshot: WatchWorkoutSnapshot) async {
        guard let activity = Activity<WatchWorkoutAttributes>.activities.first(where: { $0.id == id }) else { return }
        await activity.update(content(snapshot))
    }

    nonisolated private static func endActivity(id: String) async {
        guard let activity = Activity<WatchWorkoutAttributes>.activities.first(where: { $0.id == id }) else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
    }
}

/// Called directly on HealthKit's callback queue, before a cold launch can block MainActor.
enum WatchWorkoutActivityRequest {
    /// Re-publish the current state so the widget reads changed App Group preferences immediately.
    nonisolated static func refreshActivePreferences() async {
        for activity in Activity<WatchWorkoutAttributes>.activities {
            let content = activity.content
            guard content.state.phase != .ended else { continue }
            await activity.update(ActivityContent(state: content.state, staleDate: content.staleDate))
        }
    }

    /// Also removes orphaned activities after the iPhone process was relaunched.
    nonisolated static func finish(matching final: WatchWorkoutSnapshot) async {
        guard final.isValid, final.phase == .ended else { return }
        for activity in Activity<WatchWorkoutAttributes>.activities
        where activity.content.state.isSameWorkout(as: final) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    nonisolated static func start(mirrorID: UUID, snapshot: WatchWorkoutSnapshot) throws -> String? {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return nil }
        let abandonedIDs = Activity<WatchWorkoutAttributes>.activities.map(\.id)
        let id = try Activity.request(
            attributes: WatchWorkoutAttributes(mirrorID: mirrorID),
            content: ActivityContent(state: snapshot, staleDate: snapshot.updatedAt.addingTimeInterval(30)),
            pushType: nil
        ).id
        Task {
            for abandonedID in abandonedIDs {
                guard let activity = Activity<WatchWorkoutAttributes>.activities.first(where: { $0.id == abandonedID }) else { continue }
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        return id
    }
}
