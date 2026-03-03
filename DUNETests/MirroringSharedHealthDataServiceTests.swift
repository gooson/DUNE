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

    func persist(snapshot: SharedHealthSnapshot) async {
        persistCallCount += 1
        persistedFetchedAts.append(snapshot.fetchedAt)
    }
}

@Suite("MirroringSharedHealthDataService")
struct MirroringSharedHealthDataServiceTests {
    @Test("fetchSnapshot forwards to base and persists snapshot")
    func fetchSnapshotPersistsSnapshot() async {
        let fetchedAt = Date(timeIntervalSince1970: 1_700_000_100)
        let snapshot = makeSnapshot(fetchedAt: fetchedAt)
        let base = MockBaseSharedHealthDataService(snapshot: snapshot)
        let mirror = MockHealthSnapshotMirrorStore()
        let service = MirroringSharedHealthDataService(
            baseService: base,
            mirrorStore: mirror
        )

        let result = await service.fetchSnapshot()

        #expect(result.fetchedAt == fetchedAt)
        #expect(await base.fetchSnapshotCallCount == 1)
        #expect(await mirror.persistCallCount == 1)
        #expect(await mirror.persistedFetchedAts == [fetchedAt])
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
