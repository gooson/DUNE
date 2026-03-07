import Foundation
import Testing
@testable import DUNEWatch

@Suite("WatchExerciseHelpers")
struct WatchExerciseHelpersTests {
    private func exercise(
        id: String,
        name: String = "Bench Press",
        inputType: String = "weight_reps",
        defaultSets: Int = 3,
        defaultReps: Int? = 10,
        defaultWeightKg: Double? = 50,
        isPreferred: Bool = false,
        equipment: String? = "barbell",
        aliases: [String]? = nil
    ) -> WatchExerciseInfo {
        WatchExerciseInfo(
            id: id,
            name: name,
            inputType: inputType,
            defaultSets: defaultSets,
            defaultReps: defaultReps,
            defaultWeightKg: defaultWeightKg,
            isPreferred: isPreferred,
            equipment: equipment,
            cardioSecondaryUnit: nil,
            aliases: aliases
        )
    }

    private func entry(exerciseID: String = "bench-press", name: String = "Bench Press") -> TemplateEntry {
        TemplateEntry(
            exerciseDefinitionID: exerciseID,
            exerciseName: name,
            defaultSets: 3,
            defaultReps: 10,
            defaultWeightKg: 60,
            equipment: "barbell"
        )
    }

    @Test("exerciseSubtitle formats optional weight and applies bounds")
    func exerciseSubtitleFormatting() {
        #expect(exerciseSubtitle(sets: 3, reps: 10, weight: nil) == "3 sets · 10 reps")
        #expect(exerciseSubtitle(sets: 3, reps: 10, weight: 80) == "3 sets · 10 reps · 80.0kg")
        #expect(exerciseSubtitle(sets: 3, reps: 10, weight: 0) == "3 sets · 10 reps")
        #expect(exerciseSubtitle(sets: 3, reps: 10, weight: 501) == "3 sets · 10 reps")
    }

    @Test("uniqueByCanonical keeps first exercise for canonical duplicates")
    func uniqueByCanonicalKeepsFirst() {
        let runID = UUID().uuidString
        let first = exercise(id: "tempo-\(runID)-bench-press", name: "Tempo Bench")
        let duplicate = exercise(id: "\(runID)-bench-press", name: "Bench")
        let squat = exercise(id: "\(runID)-squat", name: "Squat")

        let result = uniqueByCanonical([first, duplicate, squat])
        #expect(result.count == 2)
        #expect(result[0].id == first.id)
        #expect(result[1].id == squat.id)
    }

    @Test("resolvedDefaults returns fallback reps when no defaults are present")
    func resolvedDefaultsFallback() {
        let runID = UUID().uuidString
        let noDefaults = exercise(
            id: "\(runID)-no-defaults",
            name: "No Defaults",
            defaultSets: 2,
            defaultReps: nil,
            defaultWeightKg: nil
        )

        let defaults = resolvedDefaults(for: noDefaults)
        #expect(defaults.reps == 10)
        #expect(defaults.weight == nil)
    }

    @Test("resolvedDefaults prefers latest set over exercise defaults")
    func resolvedDefaultsPrefersLatestSet() {
        let runID = UUID().uuidString
        let target = exercise(
            id: "\(runID)-squat",
            name: "Squat",
            defaultSets: 4,
            defaultReps: 12,
            defaultWeightKg: 60
        )
        RecentExerciseTracker.recordLatestSet(exerciseID: target.id, weight: 100, reps: 6)

        let defaults = resolvedDefaults(for: target)
        #expect(defaults.reps == 6)
        #expect(defaults.weight == 100)
    }

    @Test("snapshotFromExercise uses resolved defaults in template entry")
    func snapshotFromExerciseUsesResolvedDefaults() {
        let runID = UUID().uuidString
        let exerciseInfo = exercise(
            id: "tempo-\(runID)-deadlift-paused",
            name: "Deadlift",
            defaultSets: 4,
            defaultReps: 5,
            defaultWeightKg: 120
        )
        RecentExerciseTracker.recordLatestSet(
            exerciseID: "\(runID)-deadlift",
            weight: 130,
            reps: 3
        )

        let snapshot = snapshotFromExercise(exerciseInfo)
        #expect(snapshot.name == "Deadlift")
        #expect(snapshot.entries.count == 1)

        let entry = snapshot.entries[0]
        #expect(entry.exerciseDefinitionID == exerciseInfo.id)
        #expect(entry.defaultSets == 4)
        #expect(entry.defaultReps == 3)
        #expect(entry.defaultWeightKg == 130)
    }

    @Test("mergedRoutineTemplates prefers local template when IDs overlap")
    func mergedRoutineTemplatesPrefersLocal() {
        let templateID = UUID()
        let remote = WatchWorkoutTemplateInfo(
            id: templateID,
            name: "Remote Push",
            entries: [entry()],
            updatedAt: Date(timeIntervalSince1970: 10)
        )
        let local = WorkoutTemplate(name: "Local Push", exerciseEntries: [entry(name: "Local Bench")])
        local.id = templateID
        local.updatedAt = Date(timeIntervalSince1970: 20)

        let merged = mergedRoutineTemplates(local: [local], synced: [remote])
        #expect(merged.count == 1)
        #expect(merged[0].name == "Local Push")
        #expect(merged[0].entries.first?.exerciseName == "Local Bench")
    }

    @Test("mergedRoutineTemplates includes remote template when local store is empty")
    func mergedRoutineTemplatesIncludesRemoteFallback() {
        let remote = WatchWorkoutTemplateInfo(
            id: UUID(),
            name: "Remote Legs",
            entries: [entry(exerciseID: "squat", name: "Squat")],
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        let merged = mergedRoutineTemplates(local: [], synced: [remote])
        #expect(merged.count == 1)
        #expect(merged[0].name == "Remote Legs")
        #expect(merged[0].entries.first?.exerciseDefinitionID == "squat")
    }

    @Test("mergedRoutineTemplates sorts by most recent update")
    func mergedRoutineTemplatesSortsByDateDescending() {
        let olderRemote = WatchWorkoutTemplateInfo(
            id: UUID(),
            name: "Older Remote",
            entries: [entry(name: "Old")],
            updatedAt: Date(timeIntervalSince1970: 50)
        )
        let newerRemote = WatchWorkoutTemplateInfo(
            id: UUID(),
            name: "Newer Remote",
            entries: [entry(name: "New")],
            updatedAt: Date(timeIntervalSince1970: 150)
        )

        let merged = mergedRoutineTemplates(local: [], synced: [olderRemote, newerRemote])
        #expect(merged.count == 2)
        #expect(merged[0].name == "Newer Remote")
        #expect(merged[1].name == "Older Remote")
    }

    @Test("WatchExerciseCategory maps known inputType values")
    func watchExerciseCategoryMapping() {
        #expect(WatchExerciseCategory(inputTypeRaw: "setsRepsWeight") == .strength)
        #expect(WatchExerciseCategory(inputTypeRaw: "setsReps") == .bodyweight)
        #expect(WatchExerciseCategory(inputTypeRaw: "durationDistance") == .cardio)
        #expect(WatchExerciseCategory(inputTypeRaw: "roundsBased") == .hiit)
        #expect(WatchExerciseCategory(inputTypeRaw: "durationIntensity") == .flexibility)
        #expect(WatchExerciseCategory(inputTypeRaw: "unknown-type") == .other)
    }

    @Test("filterWatchExercises matches aliases and equipment keywords")
    func filterWatchExercisesAliasAndEquipment() {
        let bench = exercise(
            id: "bench",
            name: "Bench Press",
            equipment: "barbell",
            aliases: ["Flat Bench Press"]
        )
        let squat = exercise(
            id: "squat",
            name: "Squat",
            equipment: "smithMachine",
            aliases: ["Back Squat"]
        )

        let aliasResults = filterWatchExercises(
            exercises: [bench, squat],
            query: "flat bench",
            category: nil
        )
        #expect(aliasResults.map(\.id) == ["bench"])

        let equipmentResults = filterWatchExercises(
            exercises: [bench, squat],
            query: "스미스",
            category: nil
        )
        #expect(equipmentResults.map(\.id) == ["squat"])
    }

    @Test("filterWatchExercises combines category filter and query terms")
    func filterWatchExercisesWithCategory() {
        let run = exercise(
            id: "run",
            name: "Interval Running",
            inputType: "durationDistance",
            equipment: nil
        )
        let bike = exercise(
            id: "bike",
            name: "Bike Sprint",
            inputType: "durationDistance",
            equipment: "machine"
        )
        let burpee = exercise(
            id: "burpee",
            name: "Burpee",
            inputType: "roundsBased",
            equipment: nil
        )

        let cardioOnly = filterWatchExercises(
            exercises: [run, bike, burpee],
            query: "bike",
            category: .cardio
        )
        #expect(cardioOnly.map(\.id) == ["bike"])
    }

    @Test("groupedWatchExercisesByCategory follows fixed category order")
    func groupedWatchExercisesOrdering() {
        let exercises = [
            exercise(id: "flex", name: "Stretch", inputType: "durationIntensity"),
            exercise(id: "strength", name: "Bench", inputType: "setsRepsWeight"),
            exercise(id: "cardio", name: "Run", inputType: "durationDistance")
        ]

        let grouped = groupedWatchExercisesByCategory(exercises)
        #expect(grouped.map(\.category) == [.strength, .cardio, .flexibility])
    }

    @Test("preferredWatchExercises sorts preferred items and excludes higher-priority canonicals")
    func preferredWatchExercisesOrdering() {
        let bench = exercise(id: "bench", name: "Bench", isPreferred: true)
        let squat = exercise(id: "squat", name: "Squat", isPreferred: true)
        let run = exercise(id: "run", name: "Run", isPreferred: false)

        let result = preferredWatchExercises(
            from: [bench, squat, run],
            excludingCanonical: ["bench"],
            lastUsedTimestamps: [squat.id: 200, bench.id: 100]
        )

        #expect(result.map(\.id) == ["squat"])
    }

    @Test("prioritizedWatchExercises keeps recent before preferred before popular")
    func prioritizedWatchExercisesOrdering() {
        let recent = exercise(id: "recent", name: "Recent")
        let preferred = exercise(id: "preferred", name: "Preferred", isPreferred: true)
        let popular = exercise(id: "popular", name: "Popular")
        let other = exercise(id: "other", name: "Other")

        let ordered = prioritizedWatchExercises(
            [other, popular, preferred, recent],
            recent: [recent],
            preferred: [preferred],
            popular: [popular]
        )

        #expect(ordered.map(\.id) == ["recent", "preferred", "popular", "other"])
    }
}
