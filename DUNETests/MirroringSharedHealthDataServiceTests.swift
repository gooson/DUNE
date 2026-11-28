import Foundation
import SwiftData
import Synchronization
import Testing
@testable import DUNE

private actor MockBaseSharedHealthDataService: SharedHealthDataService {
    var invalidateCacheCallCount = 0
    var fetchSnapshotCallCount = 0

    private var snapshot: SharedHealthSnapshot

    init(snapshot: SharedHealthSnapshot) {
        self.snapshot = snapshot
    }

    func setSnapshot(_ snapshot: SharedHealthSnapshot) {
        self.snapshot = snapshot
    }

    func fetchSnapshot() async -> SharedHealthSnapshot {
        fetchSnapshotCallCount += 1
        return snapshot
    }

    func invalidateCache() async {
        invalidateCacheCallCount += 1
    }
}

private actor MockHealthSnapshotMirrorStore: HealthSnapshotMirroring {
    nonisolated let isEnabled = true
    var persistCallCount = 0
    var persistedFetchedAts: [Date] = []
    private var blocksPersist = false
    private var didStartPersist = false
    private var persistStartedContinuation: CheckedContinuation<Void, Never>?
    private var persistReleaseContinuation: CheckedContinuation<Void, Never>?

    func blockPersist() {
        blocksPersist = true
    }

    func waitUntilPersistStarts() async {
        if didStartPersist {
            return
        }
        await withCheckedContinuation { continuation in
            persistStartedContinuation = continuation
        }
    }

    func releasePersist() {
        blocksPersist = false
        persistReleaseContinuation?.resume()
        persistReleaseContinuation = nil
    }

    func persist(snapshot: SharedHealthSnapshot) async {
        persistCallCount += 1
        persistedFetchedAts.append(snapshot.fetchedAt)
        didStartPersist = true
        persistStartedContinuation?.resume()
        persistStartedContinuation = nil

        guard blocksPersist else { return }
        await withCheckedContinuation { continuation in
            persistReleaseContinuation = continuation
        }
    }
}

private actor FetchCompletionTracker {
    private(set) var completedFetchedAt: Date?

    func markCompleted(with fetchedAt: Date) {
        completedFetchedAt = fetchedAt
    }
}

@Suite("MirroringSharedHealthDataService")
struct MirroringSharedHealthDataServiceTests {
    @Test("A live runtime keeps old rows when OFF and resumes mirroring on the next foreground fetch")
    @MainActor
    func togglingInForegroundPreservesMirrorAndReturnsLiveData() async throws {
        let container = try HealthSnapshotMirrorContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let existing = HealthSnapshotMirrorRecord(payloadJSON: "legacy payload")
        context.insert(existing)
        try context.save()

        let snapshot = makeSnapshot(fetchedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let base = MockBaseSharedHealthDataService(snapshot: snapshot)
        let syncEnabled = Mutex(false)
        let service = DUNEApp.makeSharedHealthDataService(
            modelContainer: container, healthKitAvailable: true, useSeededMirror: false,
            liveService: base, isCloudSyncEnabled: { syncEnabled.withLock { $0 } }
        )
        #expect(await service.fetchSnapshot().fetchedAt == snapshot.fetchedAt)
        await service.invalidateCache()
        #expect(await base.invalidateCacheCallCount == 1)
        let descriptor = FetchDescriptor<HealthSnapshotMirrorRecord>()
        let records = try ModelContext(container).fetch(descriptor)
        #expect(records.map(\.id) == [existing.id])
        #expect(records.first?.payloadJSON == "legacy payload")

        syncEnabled.withLock { $0 = true }
        let onDate = snapshot.fetchedAt.addingTimeInterval(60)
        await base.setSnapshot(makeSnapshot(fetchedAt: onDate))
        #expect(await service.fetchSnapshot().fetchedAt == onDate)
        let deadline = ContinuousClock.now + .seconds(3)
        while try ModelContext(container).fetchCount(descriptor) == 1 && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        let onDates = try ModelContext(container).fetch(descriptor).map(\.fetchedAt)
        #expect(Set(onDates) == [existing.fetchedAt, onDate])

        syncEnabled.withLock { $0 = false }
        let later = onDate.addingTimeInterval(60)
        await base.setSnapshot(makeSnapshot(fetchedAt: later))
        #expect(await service.fetchSnapshot().fetchedAt == later)
        #expect(try ModelContext(container).fetchCount(descriptor) == 2)
    }

    @Test("Seeded and HealthKit-unavailable runtimes read existing mirrored snapshots",
          arguments: [(true, true), (false, false), (false, true)])
    @MainActor
    func runtimeSelectsMirrorReadersBeforeLiveSources(available: Bool, seeded: Bool) throws {
        let container = try HealthSnapshotMirrorContainerFactory.makeInMemoryContainer()
        let base = MockBaseSharedHealthDataService(snapshot: makeSnapshot(fetchedAt: Date()))
        let service = DUNEApp.makeSharedHealthDataService(
            modelContainer: container, healthKitAvailable: available, useSeededMirror: seeded, liveService: base
        )
        #expect(service is CloudMirroredSharedHealthDataService)
    }

    @Test("Turning sync off before a queued save preserves rows and permits a later opted-in retry")
    func queuedSaveRechecksConsent() async throws {
        let container = try HealthSnapshotMirrorContainerFactory.makeInMemoryContainer()
        let checks = Mutex([false, true, false, true, true])
        let mirror = HealthSnapshotMirrorStore(modelContainer: container, isCloudSyncEnabled: {
            checks.withLock { $0.isEmpty ? false : $0.removeFirst() }
        })
        let snapshot = makeSnapshot(fetchedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let descriptor = FetchDescriptor<HealthSnapshotMirrorRecord>()
        await mirror.persist(snapshot: snapshot) // Already off when the queued job starts.
        #expect(try ModelContext(container).fetchCount(descriptor) == 0)
        await mirror.persist(snapshot: snapshot) // Switched off while preparing the transaction.
        #expect(try ModelContext(container).fetchCount(descriptor) == 0)
        await mirror.persist(snapshot: snapshot) // Switched on again.
        #expect(try ModelContext(container).fetch(descriptor).map(\.fetchedAt) == [snapshot.fetchedAt])
    }

    @Test("fetchSnapshot returns before background persist completes")
    func fetchSnapshotDoesNotAwaitPersist() async {
        let fetchedAt = Date(timeIntervalSince1970: 1_700_000_100)
        let snapshot = makeSnapshot(fetchedAt: fetchedAt)
        let base = MockBaseSharedHealthDataService(snapshot: snapshot)
        let mirror = MockHealthSnapshotMirrorStore()
        let completionTracker = FetchCompletionTracker()
        let service = MirroringSharedHealthDataService(
            baseService: base,
            mirrorStore: mirror
        )

        await mirror.blockPersist()
        let fetchTask = Task {
            let result = await service.fetchSnapshot()
            await completionTracker.markCompleted(with: result.fetchedAt)
        }

        await mirror.waitUntilPersistStarts()
        try? await Task.sleep(for: .milliseconds(20))

        #expect(await base.fetchSnapshotCallCount == 1)
        #expect(await completionTracker.completedFetchedAt == fetchedAt)
        #expect(await mirror.persistCallCount == 1)
        #expect(await mirror.persistedFetchedAts == [fetchedAt])

        await mirror.releasePersist()
        await fetchTask.value
    }

    @Test("invalidateCache is delegated to base service")
    func invalidateCacheDelegatesToBase() async {
        let base = MockBaseSharedHealthDataService(snapshot: makeSnapshot(fetchedAt: Date()))
        let mirror = MockHealthSnapshotMirrorStore()
        let service = MirroringSharedHealthDataService(
            baseService: base,
            mirrorStore: mirror
        )

        await service.invalidateCache()

        #expect(await base.invalidateCacheCallCount == 1)
        #expect(await mirror.persistCallCount == 0)
    }

    private func makeSnapshot(fetchedAt: Date) -> SharedHealthSnapshot {
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
            fetchedAt: fetchedAt
        )
    }
}
