import Testing
@testable import DUNE

@Suite("Exercise Variant Consolidation")
struct ExerciseVariantConsolidationTests {
    let library = ExerciseLibraryService.shared

    // MARK: - Consolidated JSON count

    @Test("Exercise library contains only base exercises after consolidation")
    func exerciseCountAfterConsolidation() {
        let all = library.allExercises()
        #expect(all.count < 200, "Expected consolidated exercise count < 200, got \(all.count)")
        #expect(all.count > 100, "Expected consolidated exercise count > 100, got \(all.count)")
    }

    // MARK: - Legacy variant ID resolution

    @Test("Suffix-based variant IDs resolve to base exercise", arguments: [
        ("push-up-tempo", "push-up"),
        ("push-up-paused", "push-up"),
        ("push-up-volume", "push-up"),
        ("push-up-unilateral", "push-up"),
        ("battle-ropes-emom", "battle-ropes"),
        ("battle-ropes-amrap", "battle-ropes"),
        ("battle-ropes-ladder", "battle-ropes"),
        ("yoga-recovery-flow", "yoga"),
        ("yoga-mobility-flow", "yoga"),
        ("yoga-static-hold", "yoga"),
        ("tabata-emom", "tabata"),
        ("foam-rolling-recovery-flow", "foam-rolling"),
        ("plank-volume", "plank"),
        ("pull-up-tempo", "pull-up"),
        ("dip-chest-volume", "dip-chest"),
        ("barbell-bench-press-tempo", "barbell-bench-press"),
    ])
    func suffixVariantResolution(variantID: String, expectedBaseID: String) {
        let resolved = ExerciseLibraryService.resolvedExerciseID(for: variantID)
        #expect(resolved == expectedBaseID, "Expected \(variantID) → \(expectedBaseID), got \(resolved)")
    }

    // MARK: - Standalone merge resolution

    @Test("Standalone single-leg/arm exercises resolve to base", arguments: [
        ("single-leg-press-machine", "leg-press"),
        ("single-leg-extension-machine", "leg-extension"),
        ("single-leg-curl-machine", "leg-curl"),
        ("single-arm-shoulder-press-machine", "shoulder-press-machine"),
    ])
    func standaloneMergeResolution(variantID: String, expectedBaseID: String) {
        let resolved = ExerciseLibraryService.resolvedExerciseID(for: variantID)
        #expect(resolved == expectedBaseID, "Expected \(variantID) → \(expectedBaseID), got \(resolved)")
    }

    // MARK: - Base IDs remain unchanged

    @Test("Base exercise IDs are not modified by resolution", arguments: [
        "push-up", "pull-up", "plank", "yoga", "battle-ropes",
        "tabata", "foam-rolling", "dip-chest", "leg-press",
        "barbell-bench-press", "single-leg-deadlift",
    ])
    func baseIDsUnchanged(baseID: String) {
        let resolved = ExerciseLibraryService.resolvedExerciseID(for: baseID)
        #expect(resolved == baseID, "Base ID \(baseID) should not change, got \(resolved)")
    }

    // MARK: - exercise(byID:) fallback

    @Test("exercise(byID:) resolves legacy variant to base exercise")
    func exerciseByIDFallback() {
        // Direct base lookup
        let pushUp = library.exercise(byID: "push-up")
        #expect(pushUp != nil)
        #expect(pushUp?.id == "push-up")

        // Legacy variant lookup should resolve to base
        let pushUpTempo = library.exercise(byID: "push-up-tempo")
        #expect(pushUpTempo != nil)
        #expect(pushUpTempo?.id == "push-up")

        let dipVolume = library.exercise(byID: "dip-chest-volume")
        #expect(dipVolume != nil)
        #expect(dipVolume?.id == "dip-chest")
    }

    // MARK: - Canonical service suffix parity

    @Test("QuickStartCanonicalService handles all variant suffixes")
    func canonicalServiceHandlesAllSuffixes() {
        let suffixes = [
            "-tempo", "-paused", "-volume", "-unilateral",
            "-emom", "-amrap", "-ladder",
            "-endurance", "-intervals",
            "-recovery-flow", "-recovery",
            "-mobility-flow", "-static-hold",
        ]

        for suffix in suffixes {
            let variantID = "test-exercise\(suffix)"
            let canonical = QuickStartCanonicalService.canonicalExerciseID(for: variantID)
            #expect(canonical == "test-exercise",
                    "canonicalExerciseID did not strip \(suffix): got '\(canonical)'")
        }
    }

    // MARK: - single-leg-deadlift stays independent

    @Test("single-leg-deadlift is preserved as independent exercise")
    func singleLegDeadliftPreserved() {
        let exercise = library.exercise(byID: "single-leg-deadlift")
        #expect(exercise != nil)
        #expect(exercise?.id == "single-leg-deadlift")

        let resolved = ExerciseLibraryService.resolvedExerciseID(for: "single-leg-deadlift")
        #expect(resolved == "single-leg-deadlift")
    }

    // MARK: - Aliases preserved from variants

    @Test("Base exercise aliases include variant names for searchability")
    func aliasesIncludeVariantNames() {
        let pushUp = library.exercise(byID: "push-up")
        let aliases = pushUp?.aliases ?? []
        #expect(aliases.contains("Push-Up Tempo") || aliases.contains("푸쉬업 템포"),
                "push-up aliases should contain variant names")
    }

    // MARK: - Search still finds base via variant keywords

    @Test("Search by variant name returns base exercise")
    func searchByVariantName() {
        let results = library.search(query: "템포")
        #expect(!results.isEmpty, "Search for '템포' should return results via aliases")
    }
}
