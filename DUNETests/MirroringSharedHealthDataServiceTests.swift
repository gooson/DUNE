import Foundation
import Testing
@testable import DUNE

private actor MockBaseSharedHealthDataService: SharedHealthDataService {
    var invalidateCacheCallCount = 0
    var fetchSnapshotCallCount = 0

    private let snapshot: SharedHealthSnapshot

    init(snapshot: SharedHealthSnapshot) {
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
