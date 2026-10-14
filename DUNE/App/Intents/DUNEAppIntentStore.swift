import Foundation
import SwiftData

enum DUNEAppIntentError: LocalizedError, Sendable {
    case unavailable
    case itemNotFound
    case ineligibleHabit

    var errorDescription: String? {
        switch self {
        case .unavailable: String(localized: "App data is unavailable")
        case .itemNotFound: String(localized: "This item is no longer available")
        case .ineligibleHabit: String(localized: "This habit cannot be completed with Shortcuts")
        }
    }
}

/// Shares the app's active SwiftData container with main-process intents.
@MainActor
final class DUNEAppIntentStore {
    static let shared = DUNEAppIntentStore()

    enum CompletionResult: Equatable, Sendable {
        case completed
        case alreadyCompleted
    }

    private var container: ModelContainer?
    private let saveContext: @MainActor (ModelContext) throws -> Void

    init(saveContext: @escaping @MainActor (ModelContext) throws -> Void = { try $0.save() }) {
        self.saveContext = saveContext
    }

    func configure(container: ModelContainer) {
        self.container = container
    }

    func workoutTemplates() throws -> [WorkoutTemplateEntity] {
        let context = try modelContext()
        return try context.fetch(FetchDescriptor<WorkoutTemplate>(sortBy: [SortDescriptor(\WorkoutTemplate.updatedAt, order: .reverse)]))
            .filter { !$0.exerciseEntries.isEmpty }
            .map { WorkoutTemplateEntity(id: $0.id, name: $0.name) }
    }

    func workoutTemplates(for identifiers: [UUID]) throws -> [WorkoutTemplateEntity] {
        let requested = Set(identifiers)
        return try workoutTemplates().filter { requested.contains($0.id) }
    }

    func validateWorkoutTemplate(id: UUID) throws {
        guard try workoutTemplates(for: [id]).first != nil else {
            throw DUNEAppIntentError.itemNotFound
        }
    }

    func manualCheckHabits() throws -> [ManualCheckHabitEntity] {
        let context = try modelContext()
        return try context.fetch(FetchDescriptor<HabitDefinition>(sortBy: [SortDescriptor(\HabitDefinition.sortOrder)]))
            .filter(Self.isEligibleHabit)
            .map { ManualCheckHabitEntity(id: $0.id, name: $0.name) }
    }

    func manualCheckHabits(for identifiers: [UUID]) throws -> [ManualCheckHabitEntity] {
        let requested = Set(identifiers)
        return try manualCheckHabits().filter { requested.contains($0.id) }
    }

    func completeHabit(id: UUID, at date: Date = Date()) throws -> CompletionResult {
        guard let container else { throw DUNEAppIntentError.unavailable }
        // Keep an unsuccessful intent write out of the app's shared mainContext.
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let habits = try context.fetch(FetchDescriptor<HabitDefinition>())
        guard let habit = habits.first(where: { $0.id == id }) else {
            throw DUNEAppIntentError.itemNotFound
        }
        guard Self.isEligibleHabit(habit) else {
            throw DUNEAppIntentError.ineligibleHabit
        }

        guard let day = Calendar.current.dateInterval(of: .day, for: date) else {
            throw DUNEAppIntentError.unavailable
        }
        let start = day.start
        let end = day.end
        let logs = try context.fetch(FetchDescriptor<HabitLog>(predicate: #Predicate {
            $0.date >= start && $0.date < end
        }))
        if logs.contains(where: { $0.habitDefinition?.id == id }) {
            return .alreadyCompleted
        }

        let log = HabitLog(date: date, value: 1)
        log.habitDefinition = habit
        if habit.logs == nil { habit.logs = [] }
        habit.logs?.append(log)
        context.insert(log)
        do {
            try saveContext(context)
        } catch {
            context.rollback()
            throw error
        }
        return .completed
    }

    private func modelContext() throws -> ModelContext {
        guard let container else { throw DUNEAppIntentError.unavailable }
        return container.mainContext
    }

    private static func isEligibleHabit(_ habit: HabitDefinition) -> Bool {
        !habit.isArchived && !habit.isAutoLinked && habit.habitType == .check && habit.frequency.intervalDays == nil
    }
}
