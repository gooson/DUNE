import AppIntents
import Foundation

struct WorkoutTemplateEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Workout Template")
    static let defaultQuery = WorkoutTemplateEntityQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct WorkoutTemplateEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [WorkoutTemplateEntity] {
        try await MainActor.run {
            try DUNEAppIntentStore.shared.workoutTemplates(for: identifiers)
        }
    }

    func suggestedEntities() async throws -> [WorkoutTemplateEntity] {
        try await MainActor.run {
            try DUNEAppIntentStore.shared.workoutTemplates()
        }
    }
}

struct ManualCheckHabitEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Habit")
    static let defaultQuery = ManualCheckHabitEntityQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct ManualCheckHabitEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [ManualCheckHabitEntity] {
        try await MainActor.run {
            try DUNEAppIntentStore.shared.manualCheckHabits(for: identifiers)
        }
    }

    func suggestedEntities() async throws -> [ManualCheckHabitEntity] {
        try await MainActor.run {
            try DUNEAppIntentStore.shared.manualCheckHabits()
        }
    }
}

struct OpenWorkoutTemplateIntent: OpenIntent, TargetContentProvidingIntent {
    static let title: LocalizedStringResource = "Open Workout Template"
    static let description = IntentDescription("Open a saved workout template in DUNE.")
    static var allowedExecutionTargets: ExecutionTargets { .main }

    @Parameter(title: "Workout Template")
    var target: WorkoutTemplateEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$target)")
    }

    func perform() async throws -> some IntentResult {
        try await MainActor.run {
            try DUNEAppIntentStore.shared.validateWorkoutTemplate(id: target.id)
        }
        return .result()
    }
}

struct CompleteHabitIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete Habit"
    static let description = IntentDescription("Mark a manual check habit complete for today.")
    static var authenticationPolicy: IntentAuthenticationPolicy { .requiresLocalDeviceAuthentication }
    static var allowedExecutionTargets: ExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }

    @Parameter(title: "Habit")
    var habit: ManualCheckHabitEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Complete \(\.$habit)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = try await MainActor.run {
            try DUNEAppIntentStore.shared.completeHabit(id: habit.id)
        }
        switch result {
        case .completed:
            return .result(dialog: "Habit completed")
        case .alreadyCompleted:
            return .result(dialog: "Habit already completed today")
        }
    }
}

struct DUNEAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenWorkoutTemplateIntent(),
            phrases: ["Open a workout template in \(.applicationName)"],
            shortTitle: "Open Workout Template",
            systemImageName: "figure.strengthtraining.traditional"
        )
        AppShortcut(
            intent: CompleteHabitIntent(),
            phrases: ["Complete a habit in \(.applicationName)"],
            shortTitle: "Complete Habit",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(intent: QueryHealthInformationIntent(.latestWorkout),
                    phrases: ["Show my latest workout in \(.applicationName)"],
                    shortTitle: "Latest Workout", systemImageName: "figure.run")
        AppShortcut(intent: QueryHealthInformationIntent(.workoutSummary),
                    phrases: ["Show my workout summary in \(.applicationName)"],
                    shortTitle: "Workout Summary", systemImageName: "chart.bar")
        AppShortcut(intent: QueryHealthInformationIntent(.personalRecord),
                    phrases: ["Show my personal record in \(.applicationName)"],
                    shortTitle: "Personal Record", systemImageName: "trophy")
        AppShortcut(intent: QueryHealthInformationIntent(.latestBody),
                    phrases: ["Show my body measurements in \(.applicationName)"],
                    shortTitle: "Body Measurements", systemImageName: "figure.stand")
        AppShortcut(intent: QueryHealthInformationIntent(.sleep),
                    phrases: ["Show my sleep in \(.applicationName)"],
                    shortTitle: "Sleep", systemImageName: "bed.double")
        AppShortcut(intent: QueryHealthInformationIntent(.condition),
                    phrases: [
                        "Show my condition in \(.applicationName)",
                        "How is my condition in \(.applicationName)",
                        "Today's condition in \(.applicationName)"
                    ],
                    shortTitle: "Condition", systemImageName: "heart.text.square")
        AppShortcut(intent: QueryHealthInformationIntent(.memoSearch),
                    phrases: ["Search workout notes in \(.applicationName)"],
                    shortTitle: "Search Workout Notes", systemImageName: "text.magnifyingglass")
        AppShortcut(intent: AskDUNEHealthIntent(),
                    phrases: ["Ask \(.applicationName) about my health"],
                    shortTitle: "Ask DUNE", systemImageName: "waveform")
    }
}
