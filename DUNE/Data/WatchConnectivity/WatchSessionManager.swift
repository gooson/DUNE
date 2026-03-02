import Foundation
@preconcurrency import WatchConnectivity
import Observation
import SwiftData

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
    /// Last template snapshot pushed to Watch (used to respond to pull-requests).
    private var cachedWorkoutTemplates: [WatchWorkoutTemplateInfo] = []

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

    /// Requests the Watch app to delete a specific HKWorkout UUID.
    /// Used as a fallback when iPhone-side HealthKit deletion fails.
    func requestWatchWorkoutDeletion(workoutUUID: String) {
        guard !workoutUUID.isEmpty else { return }
        guard WCSession.isSupported() else { return }

        let payload: [String: Any] = ["deleteWorkoutUUID": workoutUUID]
        let session = WCSession.default

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                AppLogger.ui.error("Failed to request watch workout deletion: \(error.localizedDescription)")
            }
        }

        // Queue background delivery when watch is not reachable.
        if session.activationState == .activated {
            session.transferUserInfo(payload)
        }
    }

    /// Send exercise library subset to Watch for offline use.
    /// Also includes global workout settings (rest time) in the same context.
    func transferExerciseLibrary(_ exercises: [WatchExerciseInfo]) {
        guard WCSession.default.activationState == .activated else { return }

        do {
            let data = try JSONEncoder().encode(exercises)
            try updateApplicationContext(exerciseLibraryData: data)
        } catch {
            AppLogger.ui.error("Failed to transfer exercise library: \(error.localizedDescription)")
        }
    }

    /// Send workout templates to Watch so routines are available even when CloudKit sync is delayed/disabled.
    func transferWorkoutTemplates(_ templates: [WatchWorkoutTemplateInfo]) {
        cachedWorkoutTemplates = templates
        guard WCSession.default.activationState == .activated else { return }

        do {
            let data = try JSONEncoder().encode(templates)
            try updateApplicationContext(workoutTemplatesData: data)
        } catch {
            AppLogger.ui.error("Failed to transfer workout templates: \(error.localizedDescription)")
        }
    }

    /// Fetches latest templates from SwiftData and transfers them to Watch.
    func syncWorkoutTemplatesToWatch(using modelContext: ModelContext) {
        let descriptor = FetchDescriptor<WorkoutTemplate>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        do {
            let templates = try modelContext.fetch(descriptor)
            let payload = templates.map { template in
                WatchWorkoutTemplateInfo(
                    id: template.id,
                    name: template.name,
                    entries: template.exerciseEntries,
                    updatedAt: template.updatedAt
                )
            }
            transferWorkoutTemplates(payload)
        } catch {
            AppLogger.ui.error("Failed to fetch workout templates for Watch sync: \(error.localizedDescription)")
        }
    }

    /// Send updated workout settings to Watch immediately (if reachable).
    /// Also re-syncs the full exercise library via applicationContext to avoid
    /// read-modify-write race with `transferExerciseLibrary()`.
    func syncWorkoutSettingsToWatch() {
        let restSeconds = WorkoutSettingsStore.shared.restSeconds

        // Immediate message if reachable
        if WCSession.default.isReachable {
            let message: [String: Any] = ["globalRestSeconds": restSeconds, "appTheme": currentThemeRawValue]
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                AppLogger.ui.error("Failed to send workout settings: \(error.localizedDescription)")
            }
        }

        // Re-sync full context (library + settings) to avoid partial overwrite
        syncExerciseLibraryToWatch()
    }

    /// Converts the full exercise library to WatchExerciseInfo and sends via applicationContext.
    func syncExerciseLibraryToWatch() {
        let definitions = ExerciseLibraryService.shared.allExercises()
        let watchExercises = definitions.map { def in
            WatchExerciseInfo(
                id: def.id,
                name: def.localizedName,
                inputType: def.inputType.rawValue,
                defaultSets: WorkoutDefaults.setCount,
                defaultReps: (def.inputType == .setsRepsWeight || def.inputType == .setsReps) ? 10 : nil,
                defaultWeightKg: nil,
                // Map generic catch-all Equipment cases to nil so Watch shows SF Symbol fallback
                // instead of treating them identically to unknown/corrupted rawValues.
                equipment: def.equipment == .other ? nil : def.equipment.rawValue,
                cardioSecondaryUnit: def.cardioSecondaryUnit?.rawValue
            )
        }
        transferExerciseLibrary(watchExercises)
    }

    private var currentThemeRawValue: String {
        UserDefaults.standard.string(forKey: "com.dune.app.theme") ?? AppTheme.desertWarm.rawValue
    }

    private func updateApplicationContext(
        exerciseLibraryData: Data? = nil,
        workoutTemplatesData: Data? = nil
    ) throws {
        var context = WCSession.default.applicationContext
        if let exerciseLibraryData {
            context["exerciseLibrary"] = exerciseLibraryData
        }
        if let workoutTemplatesData {
            context["workoutTemplates"] = workoutTemplatesData
        }
        context["globalRestSeconds"] = WorkoutSettingsStore.shared.restSeconds
        context["appTheme"] = currentThemeRawValue
        try WCSession.default.updateApplicationContext(context)
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
                transferWorkoutTemplates(cachedWorkoutTemplates)
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
        let messageCopy = ParsedWatchIncomingMessage(from: message)
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
        let messageCopy = ParsedWatchIncomingMessage(from: message)
        replyHandler(["status": "received"])
        Task { @MainActor in
            messageHandlerTask?.cancel()
            messageHandlerTask = Task { @MainActor in
                handleDecodedMessage(messageCopy)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        let messageCopy = ParsedWatchIncomingMessage(from: userInfo)
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
    private func handleDecodedMessage(_ message: ParsedWatchIncomingMessage) {
        if message.requestExerciseLibrarySync {
            syncExerciseLibraryToWatch()
        }
        if message.requestWorkoutTemplateSync {
            transferWorkoutTemplates(cachedWorkoutTemplates)
        }

        // Handle workout completion from Watch
        if let data = message.workoutCompleteData {
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
        if let data = message.setCompletedData {
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

struct ParsedWatchIncomingMessage: Sendable {
    let workoutCompleteData: Data?
    let setCompletedData: Data?
    let requestExerciseLibrarySync: Bool
    let requestWorkoutTemplateSync: Bool

    init(from message: [String: Any]) {
        workoutCompleteData = message["workoutComplete"] as? Data
        setCompletedData = message["setCompleted"] as? Data
        requestExerciseLibrarySync = (message["requestExerciseLibrarySync"] as? Bool) == true
        requestWorkoutTemplateSync = (message["requestWorkoutTemplateSync"] as? Bool) == true
    }
}

// MARK: - Validation extensions

extension WatchWorkoutUpdate {
    /// Returns a copy with invalid heart rate samples and set data filtered out
    func validated() -> WatchWorkoutUpdate {
        var copy = self
        copy.heartRateSamples = heartRateSamples.filter(\.isValid)
        copy.completedSets = completedSets.filter(\.isValid)
        if let rpe = rpe, !(1...10).contains(rpe) {
            copy.rpe = nil
        }
        return copy
    }
}

extension WatchSetData {
    var isValid: Bool {
        if let weight, !(0...500).contains(weight) { return false }
        if let reps, !(0...1000).contains(reps) { return false }
        if let duration, !(0...28800).contains(duration) { return false }
        return true
    }
}

extension WatchHeartRateSample {
    /// Valid physiological heart rate range (bpm)
    static let validRange: ClosedRange<Double> = 20...300

    var isValid: Bool {
        Self.validRange.contains(bpm)
    }
}
