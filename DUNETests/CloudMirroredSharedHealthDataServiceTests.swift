import Foundation
import SwiftData
import Testing
@testable import DUNE

@Suite("CloudMirroredSharedHealthDataService")
struct CloudMirroredSharedHealthDataServiceTests {
    @Test("returns latest mirrored snapshot from SwiftData store")
    func returnsLatestMirroredSnapshot() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let olderPayload = HealthSnapshotMirrorMapper.Payload(
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_000),
            failedSources: [],
            todayRHR: 62,
            yesterdayRHR: 63,
            latestRHR: .init(date: Date(timeIntervalSince1970: 1_700_000_000), value: 62),
            hrv14Day: [.init(date: Date(timeIntervalSince1970: 1_700_000_000), value: 45)],
            rhr14Day: [.init(date: Date(timeIntervalSince1970: 1_700_000_000), value: 62)],
            sleep14Day: [],
            todaySleepMinutes: 0,
            yesterdaySleepMinutes: 0,
            conditionScore: 42,
            conditionStatus: "fair",
            baselineReady: nil,
            baselineProgress: nil,
            recentScores: []
        )

        let latestPayload = HealthSnapshotMirrorMapper.Payload(
            fetchedAt: Date(timeIntervalSince1970: 1_700_086_400),
            failedSources: ["todaySleepStages"],
            todayRHR: 56,
            yesterdayRHR: 58,
            latestRHR: .init(date: Date(timeIntervalSince1970: 1_700_086_400), value: 56),
            hrv14Day: [.init(date: Date(timeIntervalSince1970: 1_700_086_400), value: 61)],
            rhr14Day: [.init(date: Date(timeIntervalSince1970: 1_700_086_400), value: 56)],
            sleep14Day: [
                .init(
                    date: Date(timeIntervalSince1970: 1_700_086_400),
                    totalMinutes: 430,
                    deepMinutes: 100,
                    remMinutes: 90,
                    coreMinutes: 220,
                    awakeMinutes: 20
                )
            ],
            todaySleepMinutes: 410,
            yesterdaySleepMinutes: 390,
            conditionScore: 81,
            conditionStatus: "excellent",
            baselineReady: nil,
            baselineProgress: nil,
            recentScores: [.init(date: Date(timeIntervalSince1970: 1_700_000_000), score: 76)]
        )

        context.insert(
            HealthSnapshotMirrorRecord(
                fetchedAt: olderPayload.fetchedAt,
                syncedAt: olderPayload.fetchedAt,
                sourceDevice: "iOS",
                payloadVersion: 1,
                payloadJSON: try HealthSnapshotMirrorMapper.encode(olderPayload)
            )
        )
        context.insert(
            HealthSnapshotMirrorRecord(
                fetchedAt: latestPayload.fetchedAt,
                syncedAt: latestPayload.fetchedAt,
                sourceDevice: "iOS",
                payloadVersion: 1,
                payloadJSON: try HealthSnapshotMirrorMapper.encode(latestPayload)
            )
        )
        try context.save()

        let service = CloudMirroredSharedHealthDataService(modelContainer: container, cacheTTL: 60)
        let snapshot = await service.fetchSnapshot()

        #expect(snapshot.fetchedAt == latestPayload.fetchedAt)
        #expect(snapshot.todayRHR == 56)
        #expect(snapshot.conditionScore?.score == 81)
        #expect(snapshot.hrvSamples.map(\.value) == [61])
        #expect(snapshot.sleepDailyDurations.first?.totalMinutes == 430)
        #expect(snapshot.failedSources.contains(.todaySleepStages))
    }

    @Test("returns empty snapshot when mirror store is empty")
    func returnsEmptySnapshotWhenNoRecord() async throws {
        let container = try makeInMemoryContainer()
        let referenceDate = Date(timeIntervalSince1970: 1_700_999_999)
        let service = CloudMirroredSharedHealthDataService(
            modelContainer: container,
            cacheTTL: 60,
            nowProvider: { referenceDate }
        )

        let snapshot = await service.fetchSnapshot()

        #expect(snapshot.fetchedAt == referenceDate)
        #expect(snapshot.hrvSamples.isEmpty)
        #expect(snapshot.rhrCollection.isEmpty)
        #expect(snapshot.sleepDailyDurations.isEmpty)
        #expect(snapshot.conditionScore == nil)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: HealthSnapshotMirrorRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
