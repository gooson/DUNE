import Foundation
import SwiftData
import Testing
@testable import DUNE

@Suite("ScoreRefreshService Tests")
@MainActor
struct ScoreRefreshServiceTests {
    @Test("Read-window changes invalidate condition data and preserve unrelated scores")
    func invalidateConditionHistory() async throws {
        let container = try ModelContainer(
            for: HourlyScoreSnapshot.self,
            configurations: ModelConfiguration(
                "ScoreRefreshServiceTests-\(UUID().uuidString)",
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        )
        let context = ModelContext(container)
        let now = Date()
        let older = HourlyScoreSnapshot(
            date: Calendar.current.date(byAdding: .hour, value: -5, to: now)!,
            conditionScore: 75,
            wellnessScore: 80,
            readinessScore: 69,
            hrvValue: 54,
            rhrValue: 58,
            sleepScore: 82,
            stressScore: 37
        )
        let recent = HourlyScoreSnapshot(
            date: HourlyScoreSnapshot.hourTruncated(now),
            conditionScore: 72,
            wellnessScore: 78
        )
        let historical = HourlyScoreSnapshot(
            date: Calendar.current.date(byAdding: .day, value: -3, to: now)!,
            conditionScore: 68,
            hrvValue: 48
        )
        let archival = HourlyScoreSnapshot(
            date: Calendar.current.date(byAdding: .day, value: -10, to: now)!,
            conditionScore: 64,
            hrvValue: 47
        )
        context.insert(older)
        context.insert(recent)
        context.insert(historical)
        context.insert(archival)
        try context.save()

        let service = ScoreRefreshService(modelContainer: container)
        await service.loadTodaySparklines()
        #expect(!service.conditionSparkline.points.isEmpty)

        #expect(await service.invalidateVisibleConditionHistory())
        let cutoff = TimePeriod.day.dateRange(offset: -TimePeriod.day.scrollBufferPeriods).start

        let afterRecent = try ModelContext(container).fetch(FetchDescriptor<HourlyScoreSnapshot>())
        #expect(afterRecent.filter { $0.date >= cutoff }.allSatisfy {
            $0.conditionScore == nil && $0.hrvValue == nil && $0.rhrValue == nil
        })
        #expect(afterRecent.first { $0.date < cutoff }?.conditionScore == 64)

        let persisted = try ModelContext(container).fetch(FetchDescriptor<HourlyScoreSnapshot>())
        #expect(persisted.count == 4)
        #expect(persisted.filter { $0.date >= cutoff }.allSatisfy {
            $0.conditionScore == nil && $0.hrvValue == nil && $0.rhrValue == nil
        })
        #expect(persisted.first { $0.date < cutoff }?.conditionScore == 64)
        let retained = try #require(persisted.first { $0.wellnessScore == 80 })
        #expect(retained.readinessScore == 69)
        #expect(retained.sleepScore == 82)
        #expect(retained.stressScore == 37)
        #expect(service.conditionSparkline.points.isEmpty)
    }

    // MARK: - Stress History Integration

    @Test("Complete stress history retains oldest and latest values beyond the legacy cap")
    func completeStressHistoryBeyondLegacyLimit() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let start = Date(timeIntervalSince1970: 1_767_225_600) // 2026-01-01 00:00 UTC
        let hour: TimeInterval = 60 * 60
        let rowCount = 2_304 // 96 days, crossing three 31-day slice boundaries
        for index in 0..<rowCount {
            let score = index == rowCount - 1 ? 99.0 : (index == 0 ? 7.0 : 50.0)
            context.insert(HourlyScoreSnapshot(
                date: start.addingTimeInterval(Double(index) * hour),
                stressScore: score
            ))
        }
        try context.save()

        let service = ScoreRefreshService(modelContainer: container)
        let end = start.addingTimeInterval(Double(rowCount) * hour)
        let history = try await service.fetchStressHistory(from: start, to: end)
        let legacy = await service.fetchStressSnapshots(from: start, to: end)

        #expect(history.count == rowCount)
        #expect(history.first?.date == start)
        #expect(history.first?.score == 7)
        #expect(history.last?.date == end.addingTimeInterval(-hour))
        #expect(history.last?.score == 99)
        #expect(history.filter { $0.date == start.addingTimeInterval(31 * 24 * hour) }.count == 1)
        #expect(history.filter { $0.date == start.addingTimeInterval(62 * 24 * hour) }.count == 1)
        #expect(history.filter { $0.date == start.addingTimeInterval(93 * 24 * hour) }.count == 1)
        #expect(legacy.count == 2_000)
        #expect(legacy.last?.date == start.addingTimeInterval(1_999 * hour))
    }

    @Test("Stress history uses half-open boundaries, valid zero, and filters bad scores")
    func stressHistoryBoundariesAndValidation() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let start = Date(timeIntervalSince1970: 1_767_225_600)
        let hour: TimeInterval = 60 * 60
        let fixtures: [(offset: TimeInterval, score: Double?)] = [
            (-hour, 8), (0, 0), (hour, nil), (2 * hour, -1),
            (3 * hour, 101), (4 * hour, .nan), (5 * hour, .infinity),
            (6 * hour, 100), (7 * hour, 45)
        ]
        for fixture in fixtures {
            context.insert(HourlyScoreSnapshot(
                date: start.addingTimeInterval(fixture.offset),
                stressScore: fixture.score
            ))
        }
        try context.save()

        let result = try await ScoreRefreshService(modelContainer: container)
            .fetchStressHistory(from: start, to: start.addingTimeInterval(7 * hour))

        #expect(result.count == 2)
        #expect(result[0].date == start)
        #expect(result[0].score == 0)
        #expect(result[1].date == start.addingTimeInterval(6 * hour))
        #expect(result[1].score == 100)
    }

    @Test("Duplicate imported rows across slices resolve by update time and score tie")
    func stressHistoryDuplicatePolicyAcrossSlices() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let start = Date(timeIntervalSince1970: 1_767_227_400) // 00:30 UTC
        let boundary = start.addingTimeInterval(31 * 24 * 60 * 60)
        let earlierUpdate = start.addingTimeInterval(-10_000)
        let laterUpdate = start.addingTimeInterval(-1_000)
        let rows: [(date: Date, score: Double, updated: Date)] = [
            (boundary.addingTimeInterval(-10 * 60), 10, earlierUpdate),
            (boundary.addingTimeInterval(10 * 60), 40, laterUpdate),
            (boundary.addingTimeInterval(20 * 60), 70, laterUpdate),
            (boundary.addingTimeInterval(25 * 60), 60, laterUpdate),
            (boundary.addingTimeInterval(26 * 60), .nan, start)
        ]
        for row in rows {
            let snapshot = HourlyScoreSnapshot(date: row.date, stressScore: row.score)
            snapshot.createdAt = row.updated
            context.insert(snapshot)
        }
        try context.save()

        let result = try await ScoreRefreshService(modelContainer: container)
            .fetchStressHistory(from: start, to: boundary.addingTimeInterval(60 * 60))

        #expect(result.count == 1)
        #expect(result[0].date == boundary.addingTimeInterval(-30 * 60))
        #expect(result[0].score == 70)
    }

    @Test("Repeated fall-back wall-clock hours remain distinct absolute hours")
    func stressHistoryRetainsRepeatedDSTHours() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let parser = ISO8601DateFormatter()
        let first = try #require(parser.date(from: "2026-11-01T08:30:00Z"))
        let second = try #require(parser.date(from: "2026-11-01T09:30:00Z"))
        context.insert(HourlyScoreSnapshot(date: first, stressScore: 25))
        context.insert(HourlyScoreSnapshot(date: second, stressScore: 75))
        try context.save()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))

        let result = try await ScoreRefreshService(modelContainer: container)
            .fetchStressHistory(
                from: first.addingTimeInterval(-30 * 60),
                to: second.addingTimeInterval(30 * 60),
                calendar: calendar
            )

        #expect(result.count == 2)
        #expect(result[0].date.addingTimeInterval(60 * 60) == result[1].date)
        #expect(result.map { $0.score } == [25, 75])
    }

    @Test("Invalid ranges throw a typed error and cancelled reads cannot return partial history")
    func stressHistoryInvalidRangeAndCancellation() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let start = Date(timeIntervalSince1970: 1_767_225_600)
        context.insert(HourlyScoreSnapshot(date: start, stressScore: 42))
        try context.save()
        let service = ScoreRefreshService(modelContainer: container)

        do {
            _ = try await service.fetchStressHistory(from: start, to: start)
            Issue.record("Expected invalidDateRange")
        } catch let error as ScoreRefreshService.StressHistoryError {
            #expect(error == .invalidDateRange)
        }

        let task = Task {
            try await service.fetchStressHistory(
                from: start,
                to: start.addingTimeInterval(32 * 24 * 60 * 60)
            )
        }
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Cancelled history must not return partial or complete data")
        } catch is CancellationError {
            // Expected: cancellation is checked before fetch and before publishing.
        }
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: HourlyScoreSnapshot.self,
            configurations: ModelConfiguration(
                "ScoreRefreshServiceHistoryTests-\(UUID().uuidString)",
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        )
    }
}
