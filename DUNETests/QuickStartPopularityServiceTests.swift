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

    @Test("Canonicalize merges variant IDs into a single popular representative")
    func canonicalizedGrouping() {
        let now = Date()
        let usages: [QuickStartPopularityService.Usage] = [
            .init(exerciseDefinitionID: "pec-deck-tempo", date: now.addingTimeInterval(-300)),
            .init(exerciseDefinitionID: "pec-deck-paused", date: now.addingTimeInterval(-200)),
            .init(exerciseDefinitionID: "pec-deck", date: now),
            .init(exerciseDefinitionID: "bench-press", date: now.addingTimeInterval(-100)),
        ]

        let result = QuickStartPopularityService.popularExerciseIDs(
            from: usages,
            limit: 10,
            canonicalize: QuickStartCanonicalService.canonicalExerciseID(for:)
        )

        #expect(result.first == "pec-deck")
        #expect(result.contains("bench-press"))
        #expect(result.filter { $0.contains("pec-deck") }.count == 1)
    }

    @Test("Canonical service trims known variant suffixes and prefixes")
    func canonicalRules() {
        #expect(QuickStartCanonicalService.canonicalExerciseID(for: "pec-deck-tempo") == "pec-deck")
        #expect(QuickStartCanonicalService.canonicalExerciseID(for: "tempo-leg-extension-machine") == "leg-extension-machine")
        #expect(QuickStartCanonicalService.canonicalExerciseID(for: "bench-press-paused") == "bench-press")
    }

    @Test("Canonical service trims localized name variants")
    func canonicalNameRules() {
        #expect(QuickStartCanonicalService.canonicalExerciseName(for: "펙덱 플라이 템포") == "펙덱 플라이")
        #expect(QuickStartCanonicalService.canonicalExerciseName(for: "Pec Deck Endurance Sets") == "pec deck")
        #expect(QuickStartCanonicalService.canonicalExerciseName(for: "벤치프레스 일시정지") == "벤치프레스")
    }
}
