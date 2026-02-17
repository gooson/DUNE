import Foundation
@preconcurrency import WatchConnectivity
import Observation

/// Manages WatchConnectivity session for syncing workout data with Apple Watch
@Observable
@MainActor
final class WatchSessionManager: NSObject {
    static let shared = WatchSessionManager()

    private(set) var isReachable = false
    private(set) var isPaired = false
    private(set) var isWatchAppInstalled = false

    /// Latest workout data received from Watch
    private(set) var receivedWorkoutUpdate: WatchWorkoutUpdate?

    /// Callback for when Watch sends a completed workout
    var onWorkoutReceived: ((WatchWorkoutUpdate) -> Void)?

    /// Serializes delegate message handling — cancel-before-spawn
    private var messageHandlerTask: Task<Void, Never>?

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else {
            AppLogger.ui.info("WatchConnectivity not supported on this device")
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Send current workout state to Watch for display
    func sendWorkoutState(_ state: WatchWorkoutState) {
        guard WCSession.default.isReachable else { return }

        do {
            let data = try JSONEncoder().encode(state)
            let message: [String: Any] = ["workoutState": data]
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                AppLogger.ui.error("Failed to send workout state to Watch: \(error.localizedDescription)")
            }
        } catch {
            AppLogger.ui.error("Failed to encode workout state: \(error.localizedDescription)")
        }
    }

    /// Send exercise library subset to Watch for offline use
    func transferExerciseLibrary(_ exercises: [WatchExerciseInfo]) {
        guard WCSession.default.activationState == .activated else { return }

        do {
            let data = try JSONEncoder().encode(exercises)
            let context: [String: Any] = ["exerciseLibrary": data]
            try WCSession.default.updateApplicationContext(context)
        } catch {
            AppLogger.ui.error("Failed to transfer exercise library: \(error.localizedDescription)")
        }
    }

    /// Converts the full exercise library to WatchExerciseInfo and sends via applicationContext.
    func syncExerciseLibraryToWatch() {
        let definitions = ExerciseLibraryService.shared.allExercises()
        let watchExercises = definitions.map { def in
            WatchExerciseInfo(
                id: def.id,
                name: def.localizedName,
                inputType: def.inputType.rawValue,
                defaultSets: 3,
                defaultReps: (def.inputType == .setsRepsWeight || def.inputType == .setsReps) ? 10 : nil
            )
        }
        transferExerciseLibrary(watchExercises)
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            isPaired = session.isPaired
            isWatchAppInstalled = session.isWatchAppInstalled
            if let error {
                AppLogger.ui.error("WCSession activation failed: \(error.localizedDescription)")
            }
            // Auto-sync exercise library to Watch on successful activation
            if activationState == .activated, session.isWatchAppInstalled {
                syncExerciseLibraryToWatch()
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        // Required for iOS
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate after deactivation (e.g., watch switch)
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isReachable = session.isReachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let messageCopy = message.compactMapValues { $0 as? Data }
        Task { @MainActor in
            messageHandlerTask?.cancel()
            messageHandlerTask = Task { @MainActor in
                handleDecodedMessage(messageCopy)
            }
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
            messageHandlerTask?.cancel()
            messageHandlerTask = Task { @MainActor in
                handleDecodedMessage(messageCopy)
            }
        }
    }
}

// MARK: - Message Handling

extension WatchSessionManager {
    private func handleDecodedMessage(_ message: [String: Data]) {
        // Handle workout completion from Watch
        if let data = message["workoutComplete"] {
            do {
                var update = try JSONDecoder().decode(WatchWorkoutUpdate.self, from: data)
                update = update.validated()
                receivedWorkoutUpdate = update
                onWorkoutReceived?(update)
            } catch {
                AppLogger.ui.error("Failed to decode Watch workout: \(error.localizedDescription)")
            }
        }

        // Handle set completion from Watch
        if let data = message["setCompleted"] {
            do {
                var update = try JSONDecoder().decode(WatchWorkoutUpdate.self, from: data)
                update = update.validated()
                receivedWorkoutUpdate = update
            } catch {
                AppLogger.ui.error("Failed to decode Watch set update: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Data Transfer Objects

/// Workout state sent from iPhone to Watch
struct WatchWorkoutState: Codable, Sendable {
    let exerciseName: String
    let exerciseID: String
    let currentSet: Int
    let totalSets: Int
    let targetWeight: Double?
    let targetReps: Int?
    let isActive: Bool
}

/// Workout data received from Watch
struct WatchWorkoutUpdate: Codable, Sendable {
    let exerciseID: String
    let exerciseName: String
    var completedSets: [WatchSetData]
    let startTime: Date
    let endTime: Date?
    var heartRateSamples: [WatchHeartRateSample]

    /// Returns a copy with invalid heart rate samples and set data filtered out
    func validated() -> WatchWorkoutUpdate {
        var copy = self
        copy.heartRateSamples = heartRateSamples.filter(\.isValid)
        copy.completedSets = completedSets.filter(\.isValid)
        return copy
    }
}

struct WatchSetData: Codable, Sendable {
    let setNumber: Int
    let weight: Double?
    let reps: Int?
    let duration: TimeInterval?
    let isCompleted: Bool

    var isValid: Bool {
        if let weight, !(0...500).contains(weight) { return false }
        if let reps, !(0...1000).contains(reps) { return false }
        if let duration, !(0...28800).contains(duration) { return false }
        return true
    }
}

struct WatchHeartRateSample: Codable, Sendable {
    let bpm: Double
    let timestamp: Date

    /// Valid physiological heart rate range (bpm)
    static let validRange: ClosedRange<Double> = 20...300

    var isValid: Bool {
        Self.validRange.contains(bpm)
    }
}

/// Compact exercise info for Watch display
struct WatchExerciseInfo: Codable, Sendable {
    let id: String
    let name: String
    let inputType: String  // rawValue of ExerciseInputType
    let defaultSets: Int
    let defaultReps: Int?
}
