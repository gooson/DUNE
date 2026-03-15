import Foundation
import SwiftData

/// SharedHealthDataService implementation for environments where HealthKit is
/// unavailable (e.g., iOS app running on Mac "Designed for iPad").
/// Reads the latest snapshot mirrored through SwiftData + CloudKit.
actor CloudMirroredSharedHealthDataService: SharedHealthDataService {
    private let modelContainer: ModelContainer
    private let cacheTTL: TimeInterval
    private let nowProvider: @Sendable () -> Date

    private var cachedSnapshot: SharedHealthSnapshot?
    private var cacheExpiresAt: Date?

    init(
        modelContainer: ModelContainer,
        cacheTTL: TimeInterval = 60,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.modelContainer = modelContainer
        self.cacheTTL = cacheTTL
        self.nowProvider = nowProvider
    }

    func fetchSnapshot() async -> SharedHealthSnapshot {
        if let mockData = SimulatorAdvancedMockDataProvider.current() {
            return mockData.sharedHealthSnapshot
        }
        let now = nowProvider()
        if let cachedSnapshot,
           let cacheExpiresAt,
           now < cacheExpiresAt {
            return cachedSnapshot
        }

        let snapshot: SharedHealthSnapshot
        do {
            snapshot = try loadLatestSnapshot(referenceDate: now)
        } catch {
            AppLogger.data.error("CloudMirroredSharedHealthDataService read failed: \(error.localizedDescription)")
            snapshot = Self.emptySnapshot(referenceDate: now)
        }

        cachedSnapshot = snapshot
        cacheExpiresAt = nowProvider().addingTimeInterval(cacheTTL)
        return snapshot
    }

    func invalidateCache() async {
        cachedSnapshot = nil
        cacheExpiresAt = nil
    }

    private func loadLatestSnapshot(referenceDate: Date) throws -> SharedHealthSnapshot {
        let context = ModelContext(modelContainer)
        var descriptor = FetchDescriptor<HealthSnapshotMirrorRecord>(
            sortBy: [SortDescriptor(\HealthSnapshotMirrorRecord.fetchedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        guard let latestRecord = try context.fetch(descriptor).first else {
            return Self.emptySnapshot(referenceDate: referenceDate)
        }

        let payload = try HealthSnapshotMirrorMapper.decode(latestRecord.payloadJSON)
        let snapshot = HealthSnapshotMirrorMapper.makeSnapshot(from: payload)
        AppLogger.data.info("""
            [CloudMirroredSnapshot] Loaded — \
            steps: \(snapshot.todaySteps.map { String(format: "%.0f", $0) } ?? "nil", privacy: .public), \
            exerciseToday: \(snapshot.todayExerciseMinutes.map { String(format: "%.1f", $0) } ?? "nil", privacy: .public)min, \
            exerciseRecent: \(snapshot.recentExercise.map { String(format: "%.1f", $0.minutes) } ?? "nil", privacy: .public)min, \
            weight: \(snapshot.latestWeight.map { String(format: "%.1f", $0.value) } ?? "nil", privacy: .public)kg, \
            bmi: \(snapshot.latestBMI.map { String(format: "%.1f", $0.value) } ?? "nil", privacy: .public), \
            sleepDays: \(snapshot.sleepDailyDurations.count, privacy: .public), \
            sleepInput: \(snapshot.sleepScoreInput != nil ? "yes" : "nil", privacy: .public), \
            fetchedAt: \(snapshot.fetchedAt, privacy: .public)
            """)
        return snapshot
    }

    private static func emptySnapshot(referenceDate: Date) -> SharedHealthSnapshot {
        SharedHealthSnapshot(
            hrvSamples: [],
            todayRHR: nil,
            yesterdayRHR: nil,
            latestRHR: nil,
            rhrCollection: [],
            todaySleepStages: [],
            yesterdaySleepStages: [],
            latestSleepStages: nil,
            sleepDailyDurations: [],
            conditionScore: nil,
            baselineStatus: nil,
            recentConditionScores: [],
            failedSources: [],
            fetchedAt: referenceDate
        )
    }
}
