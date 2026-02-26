import Foundation
import Testing
@testable import DUNE

@Suite("QuickStartPopularityService")
struct QuickStartPopularityServiceTests {
    @Test("Empty usage list returns empty IDs")
    func emptyUsages() {
        let result = QuickStartPopularityService.popularExerciseIDs(from: [])
        #expect(result.isEmpty)
    }

    @Test("Zero limit returns empty IDs")
    func zeroLimit() {
        let usages = [QuickStartPopularityService.Usage(
            exerciseDefinitionID: "bench",
            date: Date()
        )]
        let result = QuickStartPopularityService.popularExerciseIDs(from: usages, limit: 0)
        #expect(result.isEmpty)
    }

    @Test("Higher usage count ranks first")
    func countPriority() {
        let now = Date()
        let usages: [QuickStartPopularityService.Usage] = [
            .init(exerciseDefinitionID: "bench", date: now),
            .init(exerciseDefinitionID: "bench", date: now.addingTimeInterval(-60)),
            .init(exerciseDefinitionID: "squat", date: now),
        ]

        let result = QuickStartPopularityService.popularExerciseIDs(from: usages, limit: 10)
        #expect(result.first == "bench")
    }

    @Test("When count ties, more recent ID ranks first")
    func recentTieBreaker() {
        let now = Date()
        let usages: [QuickStartPopularityService.Usage] = [
            .init(exerciseDefinitionID: "bench", date: now.addingTimeInterval(-120)),
            .init(exerciseDefinitionID: "squat", date: now),
        ]

        let result = QuickStartPopularityService.popularExerciseIDs(from: usages, limit: 10)
        #expect(result == ["squat", "bench"])
    }

    @Test("When count and date tie, ID sort is stable")
    func stableIDTieBreaker() {
        let now = Date()
        let usages: [QuickStartPopularityService.Usage] = [
            .init(exerciseDefinitionID: "b", date: now),
            .init(exerciseDefinitionID: "a", date: now),
        ]

        let result = QuickStartPopularityService.popularExerciseIDs(from: usages, limit: 10)
        #expect(result == ["a", "b"])
    }

    @Test("Empty IDs are ignored")
    func ignoreEmptyIDs() {
        let now = Date()
        let usages: [QuickStartPopularityService.Usage] = [
            .init(exerciseDefinitionID: "", date: now),
            .init(exerciseDefinitionID: "bench", date: now),
        ]

        let result = QuickStartPopularityService.popularExerciseIDs(from: usages, limit: 10)
        #expect(result == ["bench"])
    }
}
