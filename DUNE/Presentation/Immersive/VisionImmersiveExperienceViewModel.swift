import Foundation
import Observation

enum VisionImmersiveMode: String, CaseIterable, Identifiable {
    case atmosphere
    case recovery
    case sleepJourney

    var id: String { rawValue }

    var title: String {
        switch self {
        case .atmosphere:
            String(localized: "Atmosphere")
        case .recovery:
            String(localized: "Recovery Session")
        case .sleepJourney:
            String(localized: "Sleep Journey")
        }
    }

    var subtitle: String {
        switch self {
        case .atmosphere:
            String(localized: "Condition-driven surroundings and recovery tone.")
        case .recovery:
            String(localized: "Guided cadence for downshifting and mindful recovery.")
        case .sleepJourney:
            String(localized: "Latest sleep stages mapped into a spatial timeline.")
        }
    }
}

@Observable
@MainActor
final class VisionImmersiveExperienceViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case ready
        case failed(String)
    }

    var loadState: LoadState = .idle
    var selectedMode: VisionImmersiveMode = .atmosphere
    var summary: ImmersiveRecoverySummary?
    var message: String?
    var sessionFeedback: String?
    var isRecoverySessionActive = false
    var isSavingMindfulSession = false

    private let sharedHealthDataService: SharedHealthDataService?
    private let healthKitManager: any HealthKitManaging
    private let analyzer: ImmersiveRecoveryAnalyzing
    private var recoverySessionStartedAt: Date?

    init(
        sharedHealthDataService: SharedHealthDataService?,
        healthKitManager: any HealthKitManaging = HealthKitManager.shared,
        analyzer: ImmersiveRecoveryAnalyzing = ImmersiveRecoveryAnalyzer()
    ) {
        self.sharedHealthDataService = sharedHealthDataService
        self.healthKitManager = healthKitManager
        self.analyzer = analyzer
    }

    func loadIfNeeded() async {
        guard summary == nil, loadState != .loading else { return }
        await reload()
    }

    func reload() async {
        guard loadState != .loading else { return }

        loadState = .loading
        message = nil

        if healthKitManager.isAvailable {
            do {
                try await healthKitManager.requestAuthorization()
            } catch {
                AppLogger.healthKit.error("Immersive HealthKit authorization failed: \(error.localizedDescription)")
            }
        }

        let snapshot = await sharedHealthDataService?.fetchSnapshot()
        let generatedAt = snapshot?.fetchedAt ?? Date()
        let summary = analyzer.buildSummary(from: snapshot, generatedAt: generatedAt)

        self.summary = summary
        self.message = summary.message
        self.loadState = .ready
    }

    func startRecoverySession() {
        guard !isSavingMindfulSession else { return }
        recoverySessionStartedAt = Date()
        sessionFeedback = nil
        isRecoverySessionActive = true
        selectedMode = .recovery
    }

    func completeRecoverySession() async {
        guard !isSavingMindfulSession else { return }
        let summary = summary
        let fallbackDuration = TimeInterval((summary?.recoverySession.suggestedDurationMinutes ?? 4) * 60)
        let sessionStart = recoverySessionStartedAt ?? Date().addingTimeInterval(-fallbackDuration)
        let sessionEnd = Date()

        isSavingMindfulSession = true
        defer {
            isSavingMindfulSession = false
            isRecoverySessionActive = false
            recoverySessionStartedAt = nil
        }

        guard summary?.recoverySession.shouldPersistMindfulSession == true else {
            sessionFeedback = String(localized: "Recovery session complete.")
            return
        }

        do {
            try await healthKitManager.saveMindfulSession(start: sessionStart, end: sessionEnd)
            sessionFeedback = String(localized: "Mindful minutes saved to Health.")
        } catch {
            AppLogger.healthKit.error("Saving mindful session from immersive space failed: \(error.localizedDescription)")
            sessionFeedback = String(localized: "Recovery session complete, but Health save didn't finish.")
        }
    }

    var recoveryButtonTitle: String {
        if isSavingMindfulSession {
            return String(localized: "Saving...")
        }
        if isRecoverySessionActive {
            return String(localized: "Complete Session")
        }
        return String(localized: "Start Session")
    }

    var recoveryStatusText: String {
        if isRecoverySessionActive, let recoverySessionStartedAt {
            let elapsed = max(Int(Date().timeIntervalSince(recoverySessionStartedAt) / 60.0), 0)
            return String(localized: "Session live for \(elapsed.formatted()) min")
        }

        if let sessionFeedback {
            return sessionFeedback
        }

        guard let recoverySession = summary?.recoverySession else {
            return String(localized: "Recovery cadence will appear after the first load.")
        }

        return String(
            localized: "Suggested \(recoverySession.suggestedDurationMinutes.formatted()) min • \(recoverySession.cadence.inhaleSeconds.formatted())-\(recoverySession.cadence.exhaleSeconds.formatted()) cadence"
        )
    }
}
