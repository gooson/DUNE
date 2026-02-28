import SwiftData
import Foundation

/// Seeds mock SwiftData records for UI testing when launched with "--seed-mock".
enum TestDataSeeder {
    @MainActor
    static func seed(into context: ModelContext) {
        seedExerciseRecords(into: context)
        seedBodyCompositionRecords(into: context)
        seedInjuryRecords(into: context)
        seedHabitDefinitions(into: context)
    }

    // MARK: - Exercise Records

    @MainActor
    private static func seedExerciseRecords(into context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let exercises: [(name: String, defID: String, type: String, muscles: [MuscleGroup])] = [
            ("Bench Press", "bench-press", "strength", [.chest, .triceps]),
            ("Squat", "barbell-squat", "strength", [.quadriceps, .glutes]),
            ("Deadlift", "deadlift", "strength", [.hamstrings, .back]),
        ]

        for (index, exercise) in exercises.enumerated() {
            let date = calendar.date(byAdding: .day, value: -index, to: today) ?? today
            let record = ExerciseRecord(
                date: date,
                exerciseType: exercise.type,
                duration: Double((30 + index * 10) * 60),
                calories: Double(200 + index * 50),
                exerciseDefinitionID: exercise.defID,
                primaryMuscles: exercise.muscles,
                equipment: .barbell
            )

            // Add workout sets
            var sets: [WorkoutSet] = []
            for setNum in 1...3 {
                let set = WorkoutSet(
                    setNumber: setNum,
                    weight: Double(60 + index * 20),
                    reps: 10 - index,
                    isCompleted: true
                )
                sets.append(set)
            }
            record.sets = sets

            context.insert(record)
        }
    }

    // MARK: - Body Composition

    @MainActor
    private static func seedBodyCompositionRecords(into context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for i in 0..<3 {
            let date = calendar.date(byAdding: .day, value: -i * 7, to: today) ?? today
            let record = BodyCompositionRecord(
                date: date,
                weight: 75.0 - Double(i) * 0.3,
                bodyFatPercentage: 18.0 + Double(i) * 0.2,
                muscleMass: 32.0 + Double(i) * 0.1
            )
            context.insert(record)
        }
    }

    // MARK: - Injury Records

    @MainActor
    private static func seedInjuryRecords(into context: ModelContext) {
        let record = InjuryRecord(
            bodyPart: .knee,
            bodySide: .left,
            severity: .minor,
            startDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
            memo: "Mild pain during squats"
        )
        context.insert(record)
    }

    // MARK: - Habits

    @MainActor
    private static func seedHabitDefinitions(into context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let habits: [(name: String, icon: HabitIconCategory, type: HabitType, goal: Double, unit: String?)] = [
            ("Morning Stretch", .fitness, .check, 1.0, nil),
            ("Read", .study, .duration, 30.0, "min"),
            ("Water", .hydration, .count, 8.0, "glasses"),
        ]

        for (index, h) in habits.enumerated() {
            let definition = HabitDefinition(
                name: h.name,
                iconCategory: h.icon,
                habitType: h.type,
                goalValue: h.goal,
                goalUnit: h.unit,
                frequency: .daily,
                sortOrder: index
            )
            context.insert(definition)

            // Add a log for today for the first habit
            if index == 0 {
                let log = HabitLog(date: today, value: 1.0, completedAt: Date())
                log.habitDefinition = definition
                context.insert(log)
            }
        }
    }
}
