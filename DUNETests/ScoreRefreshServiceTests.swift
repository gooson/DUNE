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
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
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
        context.insert(older)
        context.insert(recent)
        context.insert(historical)
        try context.save()

        let service = ScoreRefreshService(modelContainer: container)
        await service.loadTodaySparklines()
        #expect(!service.conditionSparkline.points.isEmpty)

        #expect(await service.invalidateRecentConditionHistory())
        let cutoff = Date().addingTimeInterval(-ScoreRefreshService.rollingWindowSeconds)

        let afterRecent = try ModelContext(container).fetch(FetchDescriptor<HourlyScoreSnapshot>())
        #expect(afterRecent.filter { $0.date >= cutoff }.allSatisfy {
            $0.conditionScore == nil && $0.hrvValue == nil && $0.rhrValue == nil
        })
        #expect(afterRecent.first { $0.date < cutoff }?.conditionScore == 68)

        let persisted = try ModelContext(container).fetch(FetchDescriptor<HourlyScoreSnapshot>())
        #expect(persisted.count == 3)
        #expect(persisted.filter { $0.date >= cutoff }.allSatisfy {
            $0.conditionScore == nil && $0.hrvValue == nil && $0.rhrValue == nil
        })
        #expect(persisted.first { $0.date < cutoff }?.conditionScore == 68)
        let retained = try #require(persisted.first { $0.wellnessScore == 80 })
        #expect(retained.readinessScore == 69)
        #expect(retained.sleepScore == 82)
        #expect(retained.stressScore == 37)
        #expect(service.conditionSparkline.points.isEmpty)
    }
}
