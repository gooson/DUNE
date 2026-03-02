import Foundation
import HealthKit
@preconcurrency import WatchConnectivity
import Observation
import OSLog

/// Sync status for exercise library data from iPhone.
enum SyncStatus: Equatable {
    case syncing
    case synced(Date)
    case failed(String)
    case notConnected
}

/// Pure helpers for watch exercise-library sync state/request policy.
enum WatchLibrarySyncRequestPolicy {
    static let minimumInterval: TimeInterval = 8

    static func statusWhenLibraryMissing(isReachable: Bool) -> SyncStatus {
        isReachable ? .syncing : .notConnected
    }

    static func shouldRequest(
        lastRequestAt: Date?,
        now: Date,
        force: Bool,
        minimumInterval: TimeInterval = minimumInterval
    ) -> Bool {
        if force { return true }
        guard let lastRequestAt else { return true }
        return now.timeIntervalSince(lastRequestAt) >= minimumInterval
    }
}

/// Watch-side WatchConnectivity manager.
/// Receives workout state from iPhone and sends completed sets back.
@Observable
@MainActor
final class WatchConnectivityManager: NSObject {
    static let shared = WatchConnectivityManager()
    nonisolated private static let logger = Logger(subsystem: "com.raftel.dailve", category: "WatchConnectivity")

    /// Reachability state — reads directly from WCSession (per correction #46).
    var isReachable: Bool {
        WCSession.isSupported() ? WCSession.default.isReachable : false
    }

    /// Active workout state received from iPhone
    private(set) var activeWorkout: WatchWorkoutState?

    /// Exercise library transferred from iPhone
    private(set) var exerciseLibrary: [WatchExerciseInfo] = []
    /// Workout templates transferred from iPhone (fallback path when CloudKit is delayed/disabled).
    private(set) var workoutTemplates: [WatchWorkoutTemplateInfo] = []

    /// Global rest time (seconds) synced from iPhone settings.
    /// Fallback to 90s if never synced (matches iOS WorkoutSettingsStore default).
    private(set) var globalRestSeconds: TimeInterval = 90

    /// Theme raw value synced from iPhone. DUNEWatchApp resolves to AppTheme.
    private(set) var syncedThemeRawValue: String = AppTheme.desertWarm.rawValue

    /// Sync status for UI display
    private(set) var syncStatus: SyncStatus = .notConnected

    private var lastExerciseLibrarySyncRequestAt: Date?
    private var lastWorkoutTemplateSyncRequestAt: Date?

    private override init() {
        super.init()
    }

    func activate() {
        if applyUITestFixturesIfNeeded() {
            return
        }
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Allows watch UI to trigger exercise-library re-sync explicitly.
    func requestExerciseLibrarySync(force: Bool = false) {
        requestExerciseLibrarySyncIfNeeded(force: force)
    }

    /// UI-test-only fixture path to make Watch flows deterministic without WC/iPhone dependency.
    @discardableResult
    private func applyUITestFixturesIfNeeded() -> Bool {
        guard ProcessInfo.processInfo.arguments.contains("--uitesting-watch") else {
            return false
        }

        exerciseLibrary = [
            WatchExerciseInfo(
                id: "ui-test-squat",
                name: "UI Test Squat",
                inputType: "setsRepsWeight",
                defaultSets: 3,
                defaultReps: 8,
                defaultWeightKg: 40,
                equipment: "barbell",
                cardioSecondaryUnit: nil
            )
        ]
        syncStatus = .synced(Date())
        return true
    }

    /// Load any previously-received applicationContext (e.g. exerciseLibrary, globalRestSeconds).
    /// `didReceiveApplicationContext` only fires on *new* updates,
    /// so we must read the cached context after activation completes.
    private func loadCachedContext() {
        let parsed = ParsedWatchContext(from: WCSession.default.receivedApplicationContext)
        handleParsedContext(parsed)
    }

    /// Notify iPhone that a workout has started on Watch.
    func sendWorkoutStarted(templateName: String) {
        guard WCSession.default.isReachable else { return }
        let message: [String: Any] = ["workoutStarted": templateName]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            Self.logger.error("Failed to send workoutStarted: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Notify iPhone that a workout has ended on Watch.
    func sendWorkoutEnded() {
        guard WCSession.default.isReachable else { return }
        let message: [String: Any] = ["workoutEnded": true]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            Self.logger.error("Failed to send workoutEnded: \(error.localizedDescription, privacy: .public)")
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
            heartRateSamples: [],
            rpe: nil
        )

        do {
            let data = try JSONEncoder().encode(update)
            let message: [String: Any] = ["setCompleted": data]
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                Self.logger.error("Failed to send set completion: \(error.localizedDescription, privacy: .public)")
            }
        } catch {
            Self.logger.error("Failed to encode set completion: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Send completed workout back to iPhone
    func sendWorkoutCompletion(_ update: WatchWorkoutUpdate) {
        guard WCSession.default.isReachable else { return }

        do {
            let data = try JSONEncoder().encode(update)
            let message: [String: Any] = ["workoutComplete": data]
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                Self.logger.error("Failed to send workout completion: \(error.localizedDescription, privacy: .public)")
            }
        } catch {
            Self.logger.error("Failed to encode workout: \(error.localizedDescription, privacy: .public)")
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
            Self.logger.error("WCSession activation failed: \(error.localizedDescription, privacy: .public)")
            Task { @MainActor in
                syncStatus = .failed(error.localizedDescription)
            }
            return
        }
        if activationState == .activated {
            Task { @MainActor in
                syncStatus = .syncing
                loadCachedContext()
                if exerciseLibrary.isEmpty {
                    requestExerciseLibrarySyncIfNeeded(force: false)
                }
                if workoutTemplates.isEmpty {
                    requestWorkoutTemplateSyncIfNeeded(force: false)
                }
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            let needsLibrary = exerciseLibrary.isEmpty
            let needsTemplates = workoutTemplates.isEmpty
            guard needsLibrary || needsTemplates else { return }
            if session.isReachable {
                if needsLibrary {
                    syncStatus = .syncing
                    requestExerciseLibrarySyncIfNeeded(force: false)
                }
                if needsTemplates {
                    requestWorkoutTemplateSyncIfNeeded(force: false)
                }
            } else {
                if needsLibrary {
                    syncStatus = .notConnected
                }
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let parsed = ParsedWatchMessage(from: message)
        Task { @MainActor in
            handleParsedMessage(parsed)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        let parsed = ParsedWatchMessage(from: message)
        replyHandler(["status": "received"])
        Task { @MainActor in
            handleParsedMessage(parsed)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        let parsed = ParsedWatchMessage(from: userInfo)
        Task { @MainActor in
            handleParsedMessage(parsed)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let parsed = ParsedWatchContext(from: applicationContext)
        Task { @MainActor in
            handleParsedContext(parsed)
        }
    }
}

// MARK: - Sendable Message Wrappers

/// Extracts Sendable fields from a WCSession message in a nonisolated context.
private struct ParsedWatchMessage: Sendable {
    let workoutStateData: Data?
    let globalRestSeconds: Double?
    let appTheme: String?
    let deleteWorkoutUUID: String?

    init(from message: [String: Any]) {
        workoutStateData = message["workoutState"] as? Data
        globalRestSeconds = message["globalRestSeconds"] as? Double
        appTheme = message["appTheme"] as? String
        deleteWorkoutUUID = message["deleteWorkoutUUID"] as? String
    }
}

/// Extracts Sendable fields from a WCSession applicationContext in a nonisolated context.
private struct ParsedWatchContext: Sendable {
    let exerciseLibraryData: Data?
    let workoutTemplatesData: Data?
    let globalRestSeconds: Double?
    let appTheme: String?

    init(from context: [String: Any]) {
        exerciseLibraryData = context["exerciseLibrary"] as? Data
        workoutTemplatesData = context["workoutTemplates"] as? Data
        globalRestSeconds = context["globalRestSeconds"] as? Double
        appTheme = context["appTheme"] as? String
    }
}

// MARK: - Message Handling

extension WatchConnectivityManager {
    private func handleParsedMessage(_ parsed: ParsedWatchMessage) {
        if let data = parsed.workoutStateData {
            do {
                let state = try JSONDecoder().decode(WatchWorkoutState.self, from: data)
                activeWorkout = state.isActive ? state : nil
            } catch {
                Self.logger.error("Failed to decode workout state: \(error.localizedDescription, privacy: .public)")
            }
        }

        // Immediate rest time update from iPhone settings change
        if let restSeconds = parsed.globalRestSeconds,
           restSeconds.isFinite, (15...600).contains(restSeconds) {
            globalRestSeconds = restSeconds
        }

        // Theme from iPhone settings change
        if let themeRaw = parsed.appTheme, !themeRaw.isEmpty {
            syncedThemeRawValue = themeRaw
        }

        if let workoutUUID = parsed.deleteWorkoutUUID, !workoutUUID.isEmpty {
            Task {
                await deleteWorkoutFromHealthKit(uuidString: workoutUUID)
            }
        }
    }

    private func handleParsedContext(_ parsed: ParsedWatchContext) {
        if let data = parsed.exerciseLibraryData {
            do {
                exerciseLibrary = try JSONDecoder().decode([WatchExerciseInfo].self, from: data)
                syncStatus = .synced(Date())
            } catch {
                Self.logger.error("Failed to decode exercise library: \(error.localizedDescription, privacy: .public)")
                syncStatus = .failed(String(localized: "Decode error"))
            }
        } else {
            if exerciseLibrary.isEmpty {
                syncStatus = WatchLibrarySyncRequestPolicy.statusWhenLibraryMissing(isReachable: isReachable)
                requestExerciseLibrarySyncIfNeeded(force: false)
            } else {
                syncStatus = .synced(Date())
            }
        }

        if let data = parsed.workoutTemplatesData {
            do {
                workoutTemplates = try JSONDecoder().decode([WatchWorkoutTemplateInfo].self, from: data)
            } catch {
                Self.logger.error("Failed to decode workout templates: \(error.localizedDescription, privacy: .public)")
            }
        } else if workoutTemplates.isEmpty {
            requestWorkoutTemplateSyncIfNeeded(force: false)
        }

        // Global rest time from iPhone settings
        if let restSeconds = parsed.globalRestSeconds,
           restSeconds.isFinite, (15...600).contains(restSeconds) {
            globalRestSeconds = restSeconds
        }

        // Theme from iPhone settings
        if let themeRaw = parsed.appTheme, !themeRaw.isEmpty {
            syncedThemeRawValue = themeRaw
        }
    }

    private func requestExerciseLibrarySyncIfNeeded(force: Bool) {
        guard WCSession.isSupported() else { return }

        let now = Date()
        guard WatchLibrarySyncRequestPolicy.shouldRequest(
            lastRequestAt: lastExerciseLibrarySyncRequestAt,
            now: now,
            force: force
        ) else {
            return
        }
        lastExerciseLibrarySyncRequestAt = now

        let payload: [String: Any] = ["requestExerciseLibrarySync": true]
        let session = WCSession.default
        var requested = false

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                Self.logger.error("Failed to request exercise library sync: \(error.localizedDescription, privacy: .public)")
            }
            requested = true
        }

        if session.activationState == .activated {
            session.transferUserInfo(payload)
            requested = true
        }

        syncStatus = requested
            ? .syncing
            : WatchLibrarySyncRequestPolicy.statusWhenLibraryMissing(isReachable: false)
    }

    private func requestWorkoutTemplateSyncIfNeeded(force: Bool) {
        guard WCSession.isSupported() else { return }

        let now = Date()
        guard WatchLibrarySyncRequestPolicy.shouldRequest(
            lastRequestAt: lastWorkoutTemplateSyncRequestAt,
            now: now,
            force: force
        ) else {
            return
        }
        lastWorkoutTemplateSyncRequestAt = now

        let payload: [String: Any] = ["requestWorkoutTemplateSync": true]
        let session = WCSession.default

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                Self.logger.error("Failed to request workout template sync: \(error.localizedDescription, privacy: .public)")
            }
        }

        if session.activationState == .activated {
            session.transferUserInfo(payload)
        }
    }

    private func deleteWorkoutFromHealthKit(uuidString: String) async {
        guard let uuid = UUID(uuidString: uuidString) else { return }
        let store = HKHealthStore()
        let predicate = HKQuery.predicateForObject(with: uuid)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [],
            limit: 1
        )

        do {
            let workouts = try await descriptor.result(for: store)
            guard let workout = workouts.first else { return }
            try await store.delete(workout)
        } catch {
            Self.logger.error("Watch workout delete failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Watch-only extensions

extension WatchExerciseInfo: Hashable {
    // Hashable uses id only to match Identifiable semantics (Correction Log #26)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
