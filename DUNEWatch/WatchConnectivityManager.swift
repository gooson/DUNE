import Foundation
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

    /// Global rest time (seconds) synced from iPhone settings.
    /// Fallback to 90s if never synced (matches iOS WorkoutSettingsStore default).
    private(set) var globalRestSeconds: TimeInterval = 90

    /// Theme raw value synced from iPhone. DUNEWatchApp resolves to AppTheme.
    private(set) var syncedThemeRawValue: String = AppTheme.desertWarm.rawValue

    /// Sync status for UI display
    private(set) var syncStatus: SyncStatus = .notConnected

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
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
            heartRateSamples: []
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
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        // No cached state to update — isReachable is a computed property (correction #46)
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

    init(from message: [String: Any]) {
        workoutStateData = message["workoutState"] as? Data
        globalRestSeconds = message["globalRestSeconds"] as? Double
        appTheme = message["appTheme"] as? String
    }
}

/// Extracts Sendable fields from a WCSession applicationContext in a nonisolated context.
private struct ParsedWatchContext: Sendable {
    let exerciseLibraryData: Data?
    let globalRestSeconds: Double?
    let appTheme: String?

    init(from context: [String: Any]) {
        exerciseLibraryData = context["exerciseLibrary"] as? Data
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
            // P3: No exerciseLibrary key — mark synced regardless of library state.
            // The context may contain other keys, or be empty on first launch.
            syncStatus = .synced(Date())
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
