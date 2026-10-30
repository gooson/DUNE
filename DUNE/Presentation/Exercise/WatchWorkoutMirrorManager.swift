import Foundation
import HealthKit
import OSLog

/// Installed before launch UI or data-store setup to meet HealthKit's background launch window.
@MainActor
final class WatchWorkoutMirrorManager: NSObject {
    static let shared = WatchWorkoutMirrorManager()
    private let healthStore = HKHealthStore()
    private let activity = WatchWorkoutActivity()
    private var session: HKWorkoutSession?
    private var mirrorID: UUID?
    private var isObserving = false

    func refreshLiveActivityPreferences() {
        activity.refreshPreferences()
    }

    func startObserving() {
        guard !isObserving, HKHealthStore.isHealthDataAvailable() else { return }
        isObserving = true
        WatchSessionManager.shared.onWorkoutEnded = { [weak self] snapshot in
            self?.receiveWorkoutEnded(snapshot)
        }
        healthStore.workoutSessionMirroringStartHandler = { [weak self] session in
            guard session.state != .ended, session.state != .stopped else { return }
            let id = UUID()
            let now = Date()
            let reportedStart = session.startDate
            let start = reportedStart ?? now
            let initial = WatchWorkoutSnapshot(
                startedAt: start, updatedAt: now, exerciseName: String(localized: "Workout"),
                elapsedSeconds: 0, phase: session.state == .paused ? .paused : .running,
                heartRate: nil, activeCalories: 0, distanceMeters: 0,
                exerciseIconName: WorkoutActivityType(healthKit: session.workoutConfiguration.activityType).iconName
            )
            var requestedID: String?
            if reportedStart != nil {
                do {
                    requestedID = try WatchWorkoutActivityRequest.start(mirrorID: id, snapshot: initial)
                } catch {
                    AppLogger.ui.error("Unable to start mirrored workout activity: \(error.localizedDescription, privacy: .private)")
                }
            }
            let activityID = requestedID
            let allowsStartCorrection = reportedStart == nil
            Task { @MainActor in
                self?.attach(session, mirrorID: id, initial: initial, activityID: activityID,
                             allowsStartCorrection: allowsStartCorrection)
            }
        }
    }

    private func receiveWorkoutEnded(_ snapshot: WatchWorkoutSnapshot) {
        guard snapshot.isValid, snapshot.phase == .ended else { return }
        if activity.finish(matching: snapshot) {
            session?.delegate = nil
            session = nil
            mirrorID = nil
        }
        Task { await WatchWorkoutActivityRequest.finish(matching: snapshot) }
    }

    private func attach(_ incoming: HKWorkoutSession, mirrorID id: UUID, initial: WatchWorkoutSnapshot,
                        activityID: String?, allowsStartCorrection: Bool) {
        if let mirrorID { activity.finish(mirrorID: mirrorID) }
        session?.delegate = nil
        session = incoming
        incoming.delegate = self
        mirrorID = id
        activity.start(mirrorID: id, snapshot: initial, requestedID: activityID, didRequest: !allowsStartCorrection,
                       allowsStartCorrection: allowsStartCorrection)
        if incoming.state == .ended || incoming.state == .stopped { finish(incoming, at: Date()) }
    }

    private func finish(_ incoming: HKWorkoutSession, at date: Date) {
        guard session === incoming, let mirrorID else { return }
        activity.finish(mirrorID: mirrorID, at: date)
        incoming.delegate = nil
        session = nil
        self.mirrorID = nil
    }
}

extension WatchWorkoutMirrorManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState, date: Date
    ) {
        Task { @MainActor in
            guard session === workoutSession, let mirrorID else { return }
            switch toState {
            case .ended, .stopped:
                finish(workoutSession, at: date)
            case .paused, .running:
                guard var snapshot = activity.snapshot else { return }
                snapshot.elapsedSeconds = snapshot.elapsed(at: date)
                snapshot.updatedAt = max(date, snapshot.updatedAt)
                snapshot.phase = toState == .paused ? .paused : .running
                activity.receive(snapshot, mirrorID: mirrorID)
            default:
                break
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            AppLogger.ui.error("Watch workout mirror failed: \(error.localizedDescription, privacy: .private)")
            finish(workoutSession, at: Date())
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession, didDisconnectFromRemoteDeviceWithError error: Error?
    ) {
        Task { @MainActor in finish(workoutSession, at: Date()) }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession, didReceiveDataFromRemoteWorkoutSession data: [Data]
    ) {
        Task { @MainActor in
            guard session === workoutSession, let mirrorID else { return }
            for packet in data where packet.count <= 4_096 {
                do {
                    let snapshot = try JSONDecoder().decode(WatchWorkoutSnapshot.self, from: packet)
                    activity.receive(snapshot, mirrorID: mirrorID, authoritative: true)
                } catch {
                    AppLogger.ui.error("Invalid Watch workout snapshot: \(error.localizedDescription, privacy: .private)")
                }
            }
        }
    }
}
