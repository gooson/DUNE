import Foundation
import Testing
@testable import Dailve

@Suite("ExerciseLibraryService")
struct ExerciseDefinitionTests {
    let library = ExerciseLibraryService()

    @Test("Library loads 100+ exercises")
    func loadsAll() {
        let all = library.allExercises()
        #expect(all.count >= 100)
    }

    @Test("Each exercise has a non-empty name")
    func allHaveNames() {
        for exercise in library.allExercises() {
            #expect(!exercise.name.isEmpty, "Exercise \(exercise.id) has empty name")
        }
    }

    @Test("Each exercise has a non-empty localizedName")
    func allHaveLocalizedNames() {
        for exercise in library.allExercises() {
            #expect(!exercise.localizedName.isEmpty, "Exercise \(exercise.id) has empty localizedName")
        }
    }

    @Test("Each exercise has valid MET value (> 0)")
    func allHaveValidMET() {
        for exercise in library.allExercises() {
            #expect(exercise.metValue > 0, "Exercise \(exercise.name) has invalid MET: \(exercise.metValue)")
        }
    }

    @Test("Each exercise has at least one primary muscle")
    func allHavePrimaryMuscles() {
        for exercise in library.allExercises() {
            #expect(!exercise.primaryMuscles.isEmpty, "Exercise \(exercise.name) has no primary muscles")
        }
    }

    @Test("Exercise lookup by ID works")
    func lookupByID() {
        let all = library.allExercises()
        guard let first = all.first else {
            Issue.record("No exercises found")
            return
        }

        let found = library.exercise(byID: first.id)
        #expect(found != nil)
        #expect(found?.name == first.name)
    }

    @Test("Exercise lookup returns nil for unknown ID")
    func lookupUnknownID() {
        let found = library.exercise(byID: "nonexistent-id")
        #expect(found == nil)
    }

    @Test("Search finds exercises by name")
    func searchByName() {
        let results = library.search(query: "bench")
        #expect(!results.isEmpty)
        for result in results {
            let nameContains = result.name.localizedCaseInsensitiveContains("bench")
            let localizedContains = result.localizedName.localizedCaseInsensitiveContains("bench")
            #expect(nameContains || localizedContains)
        }
    }

    @Test("Search is case insensitive")
    func searchCaseInsensitive() {
        let upper = library.search(query: "SQUAT")
        let lower = library.search(query: "squat")
        #expect(upper.count == lower.count)
    }

    @Test("Search returns empty for no match")
    func searchNoMatch() {
        let results = library.search(query: "zzzznonexistent")
        #expect(results.isEmpty)
    }

    @Test("Filter by muscle group returns results")
    func filterByMuscle() {
        let chestExercises = library.exercises(forMuscle: .chest)
        #expect(!chestExercises.isEmpty)
        for exercise in chestExercises {
            let hasChest = exercise.primaryMuscles.contains(.chest)
                || exercise.secondaryMuscles.contains(.chest)
            #expect(hasChest, "\(exercise.name) doesn't target chest")
        }
    }

    @Test("Filter by category returns results")
    func filterByCategory() {
        let strengthExercises = library.exercises(forCategory: .strength)
        #expect(!strengthExercises.isEmpty)
        for exercise in strengthExercises {
            #expect(exercise.category == .strength)
        }
    }

    @Test("Filter by equipment returns results")
    func filterByEquipment() {
        let barbellExercises = library.exercises(forEquipment: .barbell)
        #expect(!barbellExercises.isEmpty)
        for exercise in barbellExercises {
            #expect(exercise.equipment == .barbell)
        }
    }

    @Test("All exercise IDs are unique")
    func uniqueIDs() {
        let all = library.allExercises()
        let ids = all.map(\.id)
        let uniqueIDs = Set(ids)
        #expect(ids.count == uniqueIDs.count, "Duplicate IDs found")
    }
}
