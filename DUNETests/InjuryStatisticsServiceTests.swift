import Foundation
import Testing
@testable import DUNE

@Suite("InjuryStatisticsService")
struct InjuryStatisticsServiceTests {
    let service = InjuryStatisticsService()

    // MARK: - computeStatistics

    @Test("empty injuries returns zero counts")
    func emptyInjuries() {
        let stats = service.computeStatistics(from: [])
        #expect(stats.totalCount == 0)
        #expect(stats.activeCount == 0)
        #expect(stats.frequencyByBodyPart.isEmpty)
        #expect(stats.averageRecoveryDays == nil)
        #expect(stats.longestRecoveryDays == nil)
    }

    @Test("counts active and total injuries")
    func countsCorrect() {
        let injuries = [
            makeInjury(bodyPart: .knee, endDate: nil),
            makeInjury(bodyPart: .ankle, endDate: nil),
            makeInjury(bodyPart: .knee, endDate: Date()),
        ]
        let stats = service.computeStatistics(from: injuries)
        #expect(stats.totalCount == 3)
        #expect(stats.activeCount == 2)
    }

    @Test("frequency sorted descending")
    func frequencySorted() {
        let injuries = [
            makeInjury(bodyPart: .knee),
            makeInjury(bodyPart: .knee),
            makeInjury(bodyPart: .ankle),
            makeInjury(bodyPart: .knee),
            makeInjury(bodyPart: .shoulder),
        ]
        let stats = service.computeStatistics(from: injuries)
        #expect(stats.frequencyByBodyPart.first?.bodyPart == .knee)
        #expect(stats.frequencyByBodyPart.first?.count == 3)
    }

    @Test("average recovery days computed correctly")
    func averageRecovery() {
        let calendar = Calendar.current
        let now = Date()
        let injuries = [
            makeInjury(
                startDate: calendar.date(byAdding: .day, value: -10, to: now) ?? now,
                endDate: now
            ),
            makeInjury(
                startDate: calendar.date(byAdding: .day, value: -20, to: now) ?? now,
                endDate: now
            ),
        ]
        let stats = service.computeStatistics(from: injuries)
        #expect(stats.averageRecoveryDays != nil)
        // (10 + 20) / 2 = 15
        #expect(stats.averageRecoveryDays == 15.0)
    }

    @Test("longest recovery days computed correctly")
    func longestRecovery() {
        let calendar = Calendar.current
        let now = Date()
        let injuries = [
            makeInjury(
                startDate: calendar.date(byAdding: .day, value: -5, to: now) ?? now,
                endDate: now
            ),
            makeInjury(
                startDate: calendar.date(byAdding: .day, value: -30, to: now) ?? now,
                endDate: now
            ),
        ]
        let stats = service.computeStatistics(from: injuries)
        #expect(stats.longestRecoveryDays == 30)
    }

    // MARK: - computeVolumeComparisons

    @Test("volume comparison with empty exercise dates")
    func emptyExerciseDates() {
        let injuries = [makeInjury(bodyPart: .knee)]
        let comparisons = service.computeVolumeComparisons(injuries: injuries, exerciseDates: [])
        #expect(comparisons.count == 1)
        #expect(comparisons.first?.preInjuryCount == 0)
        #expect(comparisons.first?.duringInjuryCount == 0)
    }

    @Test("volume comparison counts pre/during/post correctly")
    func volumeCountsCorrect() {
        let calendar = Calendar.current
        let now = Date()
        let injuryStart = calendar.date(byAdding: .day, value: -20, to: now) ?? now
        let injuryEnd = calendar.date(byAdding: .day, value: -5, to: now) ?? now

        let injury = InjuryInfo(
            id: UUID(),
            bodyPart: .knee,
            bodySide: nil,
            severity: .moderate,
            startDate: injuryStart,
            endDate: injuryEnd,
            memo: ""
        )

        // Generate exercise dates: 3 before, 2 during, 1 after
        var exerciseDates: [Date] = []
        // Before: day -25, -23, -21
        for offset in [-25, -23, -21] {
            exerciseDates.append(calendar.date(byAdding: .day, value: offset, to: now) ?? now)
        }
        // During: day -15, -10
        for offset in [-15, -10] {
            exerciseDates.append(calendar.date(byAdding: .day, value: offset, to: now) ?? now)
        }
        // After: day -3
        exerciseDates.append(calendar.date(byAdding: .day, value: -3, to: now) ?? now)

        let comparisons = service.computeVolumeComparisons(injuries: [injury], exerciseDates: exerciseDates)
        #expect(comparisons.count == 1)

        let comp = comparisons[0]
        #expect(comp.preInjuryCount == 3)
        #expect(comp.duringInjuryCount == 2)
        #expect(comp.postInjuryCount == 1)
    }

    @Test("zero comparisonWindowDays returns empty")
    func zeroWindowDays() {
        let injuries = [makeInjury(bodyPart: .knee)]
        let comparisons = service.computeVolumeComparisons(
            injuries: injuries,
            exerciseDates: [Date()],
            comparisonWindowDays: 0
        )
        #expect(comparisons.isEmpty)
    }

    @Test("negative comparisonWindowDays returns empty")
    func negativeWindowDays() {
        let injuries = [makeInjury(bodyPart: .knee)]
        let comparisons = service.computeVolumeComparisons(
            injuries: injuries,
            exerciseDates: [Date()],
            comparisonWindowDays: -5
        )
        #expect(comparisons.isEmpty)
    }

    @Test("active injury has nil postInjuryCount")
    func activeInjuryNoPost() {
        let calendar = Calendar.current
        let now = Date()
        let injuryStart = calendar.date(byAdding: .day, value: -10, to: now) ?? now

        let injury = InjuryInfo(
            id: UUID(),
            bodyPart: .ankle,
            bodySide: .left,
            severity: .severe,
            startDate: injuryStart,
            endDate: nil,
            memo: ""
        )

        let comparisons = service.computeVolumeComparisons(injuries: [injury], exerciseDates: [now])
        #expect(comparisons.first?.postInjuryCount == nil)
    }

    // MARK: - Helpers

    private func makeInjury(
        bodyPart: BodyPart = .knee,
        severity: InjurySeverity = .moderate,
        startDate: Date = Date().addingTimeInterval(-86400 * 10),
        endDate: Date? = nil
    ) -> InjuryInfo {
        InjuryInfo(
            id: UUID(),
            bodyPart: bodyPart,
            bodySide: nil,
            severity: severity,
            startDate: startDate,
            endDate: endDate,
            memo: ""
        )
    }
}
