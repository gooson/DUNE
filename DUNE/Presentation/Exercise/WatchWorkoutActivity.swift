import ActivityKit
import Foundation
import OSLog

@MainActor
protocol WatchWorkoutActivityDriving {
    func start(mirrorID: UUID, snapshot: WatchWorkoutSnapshot, sampledAt: Date) throws -> String?
    func update(id: String, snapshot: WatchWorkoutSnapshot, sampledAt: Date) async
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
        let sampledAt: Date
        var requestedID: String?
        var didRequest = false
    }
    private var pending: [Update] = []
    private var updateTask: Task<Void, Never>?
    private var activityID: String?
    private var activityMirrorID: UUID?
    private var attemptedMirrorID: UUID?
    private var acceptsInitialStartCorrection = false
    private var lastWatchUpdate: Date?
    private var phaseObservations: [(phase: WatchWorkoutSnapshot.Phase, date: Date)] = []
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
        lastWatchUpdate = nil
        phaseObservations = [(snapshot.phase, snapshot.updatedAt)]
        // An unidentified placeholder must not become a stranded system activity.
        if !allowsStartCorrection {
            enqueue(snapshot, mirrorID: mirrorID, requestedID: requestedID, didRequest: didRequest)
        }
        if let final = endedSnapshotsByStart[snapshot.startedAt] {
            finish(matching: final)
        }
    }

    func receive(_ incoming: WatchWorkoutSnapshot, mirrorID: UUID) {
        guard self.mirrorID == mirrorID, let current = snapshot, current.phase != .ended,
              incoming.isValid else { return }
        guard acceptsInitialStartCorrection || abs(incoming.startedAt.timeIntervalSince(current.startedAt)) < 2 else { return }
        if let lastWatchUpdate {
            guard incoming.updatedAt >= lastWatchUpdate else { return }
        } else if incoming.updatedAt < current.updatedAt && !acceptsInitialStartCorrection {
            guard current.isSameWorkout(as: incoming) else { return }
        }

        var value = incoming
        // Buffered measurements can precede a pause or resume already observed on the phone.
        if incoming.phase != .ended {
            for observation in phaseObservations where observation.date > incoming.updatedAt && value.phase != observation.phase {
                value.elapsedSeconds = value.elapsed(at: observation.date)
                value.updatedAt = observation.date
                value.phase = observation.phase
            }
        }
        guard value.isValid else { return }
        phaseObservations.removeAll { $0.date <= incoming.updatedAt }
        acceptsInitialStartCorrection = false
        lastWatchUpdate = incoming.updatedAt
        snapshot = value
        enqueue(value, mirrorID: mirrorID)
        if let final = endedSnapshotsByStart[incoming.startedAt] {
            finish(matching: final)
        }
    }

    func receivePhase(_ phase: WatchWorkoutSnapshot.Phase, at date: Date, mirrorID: UUID) {
        guard self.mirrorID == mirrorID, var current = snapshot, current.phase != .ended,
              phase != .ended, date.timeIntervalSinceReferenceDate.isFinite, date >= (lastWatchUpdate ?? current.startedAt),
              phaseObservations.last.map({ date >= $0.date }) ?? true else { return }
        if let last = phaseObservations.last, last.phase == phase && last.date == date { return }
        phaseObservations.append((phase, date))
        guard !acceptsInitialStartCorrection, phase != current.phase else { return }
        current.elapsedSeconds = current.elapsed(at: date)
        current.updatedAt = date
        current.phase = phase
        guard current.isValid else { return }
        snapshot = current
        enqueue(current, mirrorID: mirrorID)
    }

    func finish(mirrorID: UUID, at date: Date = Date()) {
        guard self.mirrorID == mirrorID, var final = snapshot, final.phase != .ended else { return }
        final.elapsedSeconds = final.elapsed(at: date)
        final.updatedAt = max(date, final.updatedAt)
        final.phase = .ended
        snapshot = final
        enqueue(final, mirrorID: mirrorID)
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
        enqueue(final, mirrorID: mirrorID)
        return true
    }

    func waitForPendingUpdates() async { await updateTask?.value }

    /// Re-publish the latest mirrored state after a preference change, in Watch update order.
    func refreshPreferences() {
        guard let mirrorID, let snapshot, snapshot.phase != .ended,
              !acceptsInitialStartCorrection else { return }
        enqueue(snapshot, mirrorID: mirrorID)
    }

    private func enqueue(_ snapshot: WatchWorkoutSnapshot, mirrorID: UUID,
                         requestedID: String? = nil, didRequest: Bool = false) {
        let sampledAt = lastWatchUpdate ?? phaseObservations.first?.date ?? snapshot.updatedAt
        let update = Update(mirrorID: mirrorID, snapshot: snapshot, sampledAt: sampledAt,
                            requestedID: requestedID, didRequest: didRequest)
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
                    await driver.update(id: activityID, snapshot: value, sampledAt: update.sampledAt)
                } else if attemptedMirrorID != id {
                    attemptedMirrorID = id
                    do {
                        activityID = try driver.start(mirrorID: id, snapshot: value, sampledAt: update.sampledAt)
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
    func start(mirrorID: UUID, snapshot: WatchWorkoutSnapshot, sampledAt: Date) throws -> String? {
        try WatchWorkoutActivityRequest.start(mirrorID: mirrorID, snapshot: snapshot, sampledAt: sampledAt)
    }

    func update(id: String, snapshot: WatchWorkoutSnapshot, sampledAt: Date) async {
        await Self.updateActivity(id: id, snapshot: snapshot, sampledAt: sampledAt)
    }

    func end(id: String) async { await Self.endActivity(id: id) }

    nonisolated private static func updateActivity(id: String, snapshot: WatchWorkoutSnapshot, sampledAt: Date) async {
        guard let activity = Activity<WatchWorkoutAttributes>.activities.first(where: { $0.id == id }) else { return }
        await activity.update(WatchWorkoutActivityRequest.content(snapshot, sampledAt: sampledAt))
    }

    nonisolated private static func endActivity(id: String) async {
        guard let activity = Activity<WatchWorkoutAttributes>.activities.first(where: { $0.id == id }) else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
    }
}

/// Called directly on HealthKit's callback queue, before a cold launch can block MainActor.
enum WatchWorkoutActivityRequest {
    nonisolated static func content(
        _ snapshot: WatchWorkoutSnapshot, sampledAt: Date
    ) -> ActivityContent<WatchWorkoutAttributes.ContentState> {
        // HealthKit may deliver several minutes of samples together while iOS is suspended.
        ActivityContent(
            state: .init(snapshot: snapshot, preferences: .read()),
            staleDate: sampledAt.addingTimeInterval(5 * 60)
        )
    }

    /// Also removes orphaned activities after the iPhone process was relaunched.
    nonisolated static func finish(matching final: WatchWorkoutSnapshot) async {
        guard final.isValid, final.phase == .ended else { return }
        for activity in Activity<WatchWorkoutAttributes>.activities
        where activity.content.state.snapshot.isSameWorkout(as: final) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    nonisolated static func start(mirrorID: UUID, snapshot: WatchWorkoutSnapshot, sampledAt: Date) throws -> String? {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return nil }
        let abandonedIDs = Activity<WatchWorkoutAttributes>.activities.map(\.id)
        let id = try Activity.request(
            attributes: WatchWorkoutAttributes(mirrorID: mirrorID),
            content: content(snapshot, sampledAt: sampledAt),
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
