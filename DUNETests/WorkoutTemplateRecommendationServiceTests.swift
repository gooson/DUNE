import Foundation
import Testing
@testable import DUNE

@Suite("WorkoutTemplateRecommendationService")
struct WorkoutTemplateRecommendationServiceTests {
    private let service = WorkoutTemplateRecommendationService()
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min)) ?? .distantPast
    }

    private func workout(
        id: String,
        type: String,
        activityType: WorkoutActivityType,
        date: Date,
        durationMinutes: Double
    ) -> WorkoutSummary {
        WorkoutSummary(
            id: id,
            type: type,
            activityType: activityType,
            duration: durationMinutes * 60,
            calories: nil,
            distance: nil,
            date: date
        )
    }

    @Test("recommends repeated sequential workouts inside target window")
    func recommendsRepeatedSequence() {
        let reference = date(2026, 3, 7, 12, 0)
        let workouts: [WorkoutSummary] = [
            workout(id: "a1", type: "Running", activityType: .running, date: date(2026, 3, 1, 7, 0), durationMinutes: 18),
            workout(id: "a2", type: "Core", activityType: .coreTraining, date: date(2026, 3, 1, 7, 21), durationMinutes: 10),

            workout(id: "b1", type: "Running", activityType: .running, date: date(2026, 3, 3, 7, 5), durationMinutes: 17),
            workout(id: "b2", type: "Core", activityType: .coreTraining, date: date(2026, 3, 3, 7, 23), durationMinutes: 11),

            workout(id: "c1", type: "Running", activityType: .running, date: date(2026, 3, 6, 7, 8), durationMinutes: 19),
            workout(id: "c2", type: "Core", activityType: .coreTraining, date: date(2026, 3, 6, 7, 30), durationMinutes: 9),
        ]

        let result = service.recommendTemplates(
            from: workouts,
            config: .init(lookbackDays: 21, targetWindowMinutes: 35, maxSessionGapMinutes: 10, minimumFrequency: 3, maxRecommendations: 3),
            referenceDate: reference
        )

        #expect(result.count == 1)
        #expect(result.first?.frequency == 3)
        #expect(result.first?.sequenceTypes == [.running, .coreTraining])
        #expect(result.first?.averageDurationMinutes ?? 0 > 25)
    }

    @Test("splits sessions when gap exceeds threshold")
    func splitsSessionsByGapThreshold() {
        let reference = date(2026, 3, 7, 12, 0)
        let workouts: [WorkoutSummary] = [
            workout(id: "a1", type: "Running", activityType: .running, date: date(2026, 3, 1, 7, 0), durationMinutes: 20),
            workout(id: "a2", type: "Core", activityType: .coreTraining, date: date(2026, 3, 1, 7, 40), durationMinutes: 10), // 20min gap

            workout(id: "b1", type: "Running", activityType: .running, date: date(2026, 3, 3, 7, 0), durationMinutes: 20),
            workout(id: "b2", type: "Core", activityType: .coreTraining, date: date(2026, 3, 3, 7, 40), durationMinutes: 10),

            workout(id: "c1", type: "Running", activityType: .running, date: date(2026, 3, 6, 7, 0), durationMinutes: 20),
            workout(id: "c2", type: "Core", activityType: .coreTraining, date: date(2026, 3, 6, 7, 40), durationMinutes: 10),
        ]

        let result = service.recommendTemplates(
            from: workouts,
            config: .init(lookbackDays: 21, targetWindowMinutes: 35, maxSessionGapMinutes: 10, minimumFrequency: 3, maxRecommendations: 3),
            referenceDate: reference
        )

        // Running and Core become separate templates because each pair exceeds max gap.
        #expect(result.count == 2)
        #expect(result.map(\.sequenceTypes).contains([.running]))
        #expect(result.map(\.sequenceTypes).contains([.coreTraining]))
    }

    @Test("ignores sessions that exceed target window")
    func filtersOverWindowSessions() {
        let reference = date(2026, 3, 7, 12, 0)
        let workouts: [WorkoutSummary] = [
            workout(id: "a1", type: "Running", activityType: .running, date: date(2026, 3, 1, 7, 0), durationMinutes: 40),
            workout(id: "a2", type: "Core", activityType: .coreTraining, date: date(2026, 3, 1, 7, 45), durationMinutes: 10),

            workout(id: "b1", type: "Running", activityType: .running, date: date(2026, 3, 3, 7, 0), durationMinutes: 38),
            workout(id: "b2", type: "Core", activityType: .coreTraining, date: date(2026, 3, 3, 7, 43), durationMinutes: 12),

            workout(id: "c1", type: "Running", activityType: .running, date: date(2026, 3, 6, 7, 0), durationMinutes: 39),
            workout(id: "c2", type: "Core", activityType: .coreTraining, date: date(2026, 3, 6, 7, 45), durationMinutes: 9),
        ]

        let result = service.recommendTemplates(
            from: workouts,
            config: .init(lookbackDays: 21, targetWindowMinutes: 30, maxSessionGapMinutes: 10, minimumFrequency: 3, maxRecommendations: 3),
            referenceDate: reference
        )

        #expect(result.isEmpty)
    }
}
