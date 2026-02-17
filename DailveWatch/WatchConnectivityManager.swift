import Foundation
@preconcurrency import WatchConnectivity
import Observation

/// Watch-side WatchConnectivity manager.
/// Receives workout state from iPhone and sends completed sets back.
@Observable
@MainActor
final class WatchConnectivityManager: NSObject {
    static let shared = WatchConnectivityManager()

    /// Reachability state — reads directly from WCSession (per correction #46).
    var isReachable: Bool {
        WCSession.isSupported() ? WCSession.default.isReachable : false
    }

    /// Active workout state received from iPhone
    private(set) var activeWorkout: WatchWorkoutState?

    /// Exercise library transferred from iPhone
    private(set) var exerciseLibrary: [WatchExerciseInfo] = []

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Notify iPhone that a workout has started on Watch.
    func sendWorkoutStarted(templateName: String) {
        guard WCSession.default.isReachable else { return }
        let message: [String: Any] = ["workoutStarted": templateName]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Failed to send workoutStarted: \(error.localizedDescription)")
        }
    }

    /// Notify iPhone that a workout has ended on Watch.
    func sendWorkoutEnded() {
        guard WCSession.default.isReachable else { return }
        let message: [String: Any] = ["workoutEnded": true]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Failed to send workoutEnded: \(error.localizedDescription)")
        }
    }

    /// Send completed set data back to iPhone
    func sendSetCompletion(_ setData: WatchSetData, exerciseID: String, exerciseName: String) {
        guard WCSession.default.isReachable else { return }

        let update = WatchWorkoutUpdate(
            exerciseID: exerciseID,
            exerciseName: exerciseName,
            completedSets: [setData],
            startTime: Date(),
            endTime: nil,
            heartRateSamples: []
        )

        do {
            let data = try JSONEncoder().encode(update)
            let message: [String: Any] = ["setCompleted": data]
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                print("Failed to send set completion: \(error.localizedDescription)")
            }
        } catch {
            print("Failed to encode set completion: \(error.localizedDescription)")
        }
    }

    /// Send completed workout back to iPhone
    func sendWorkoutCompletion(_ update: WatchWorkoutUpdate) {
        guard WCSession.default.isReachable else { return }

        do {
            let data = try JSONEncoder().encode(update)
            let message: [String: Any] = ["workoutComplete": data]
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                print("Failed to send workout completion: \(error.localizedDescription)")
            }
        } catch {
            print("Failed to encode workout: \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("WCSession activation failed: \(error.localizedDescription)")
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        // No cached state to update — isReachable is a computed property (correction #46)
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let messageCopy = message.compactMapValues { $0 as? Data }
        Task { @MainActor in
            handleMessage(messageCopy)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        let messageCopy = message.compactMapValues { $0 as? Data }
        replyHandler(["status": "received"])
        Task { @MainActor in
            handleMessage(messageCopy)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let contextCopy = applicationContext.compactMapValues { $0 as? Data }
        Task { @MainActor in
            handleContext(contextCopy)
        }
    }
}

// MARK: - Message Handling

extension WatchConnectivityManager {
    private func handleMessage(_ message: [String: Data]) {
        if let data = message["workoutState"] {
            do {
                let state = try JSONDecoder().decode(WatchWorkoutState.self, from: data)
                activeWorkout = state.isActive ? state : nil
            } catch {
                print("Failed to decode workout state: \(error.localizedDescription)")
            }
        }
    }

    private func handleContext(_ context: [String: Data]) {
        if let data = context["exerciseLibrary"] {
            do {
                exerciseLibrary = try JSONDecoder().decode([WatchExerciseInfo].self, from: data)
            } catch {
                print("Failed to decode exercise library: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Shared DTOs (mirrored from iOS app)

struct WatchWorkoutState: Codable, Sendable {
    let exerciseName: String
    let exerciseID: String
    let currentSet: Int
    let totalSets: Int
    let targetWeight: Double?
    let targetReps: Int?
    let isActive: Bool
}

struct WatchWorkoutUpdate: Codable, Sendable {
    let exerciseID: String
    let exerciseName: String
    let completedSets: [WatchSetData]
    let startTime: Date
    let endTime: Date?
    let heartRateSamples: [WatchHeartRateSample]
}

struct WatchSetData: Codable, Sendable {
    let setNumber: Int
    let weight: Double?
    let reps: Int?
    let duration: TimeInterval?
    let isCompleted: Bool
}

struct WatchHeartRateSample: Codable, Sendable {
    let bpm: Double
    let timestamp: Date
}

struct WatchExerciseInfo: Codable, Sendable, Hashable {
    let id: String
    let name: String
    let inputType: String
    let defaultSets: Int
    let defaultReps: Int?

    // Hashable uses id only to match Identifiable semantics (Correction Log #26)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
