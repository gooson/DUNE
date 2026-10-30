import AppIntents
import Foundation
import UIKit

struct HealthExerciseEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Exercise")
    static let defaultQuery = HealthExerciseEntityQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct HealthExerciseEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [HealthExerciseEntity] {
        try await MainActor.run {
            try HealthQueryIntentAccess.requireProtectedData()
            let wanted = Set(identifiers)
            return ExerciseLibraryService.shared.allExercises()
                .filter { wanted.contains($0.id) }
                .map { HealthExerciseEntity(id: $0.id, name: $0.localizedName) }
        }
    }

    func suggestedEntities() async throws -> [HealthExerciseEntity] {
        try await MainActor.run {
            try HealthQueryIntentAccess.requireProtectedData()
            return ExerciseLibraryService.shared.allExercises().prefix(40)
                .map { HealthExerciseEntity(id: $0.id, name: $0.localizedName) }
        }
    }
}

struct HealthWorkoutEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Workout")
    static let defaultQuery = HealthWorkoutEntityQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct HealthWorkoutEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [HealthWorkoutEntity] {
        try await MainActor.run { try HealthQueryIntentAccess.requireProtectedData() }
        var seen: Set<String> = []
        let ids = Array(identifiers.lazy.filter {
            $0.count <= 200 && Self.hasSourcePrefix($0) && seen.insert($0).inserted
        }.prefix(40))
        guard !ids.isEmpty else { return [] }
        let interval = HealthQueryPeriod.last365Days.interval(endingAt: Date())
        let result = try await HealthQueryService.shared.execute(
            HealthQueryRequest(kind: .workoutSummary, interval: interval, limit: 40, workoutIDs: ids)
        )
        let wanted = Set(ids)
        let resolved = Dictionary(result.records.filter { wanted.contains($0.id) }.map {
            ($0.id, HealthWorkoutEntity(id: $0.id, name: $0.name))
        }, uniquingKeysWith: { first, _ in first })
        try await MainActor.run { try HealthQueryIntentAccess.requireProtectedData() }
        return ids.compactMap { resolved[$0] }
    }

    func suggestedEntities() async throws -> [HealthWorkoutEntity] {
        try await recentWorkouts()
    }

    private func recentWorkouts() async throws -> [HealthWorkoutEntity] {
        try await MainActor.run { try HealthQueryIntentAccess.requireProtectedData() }
        let interval = HealthQueryPeriod.last365Days.interval(endingAt: Date())
        let result = try await HealthQueryService.shared.execute(
            HealthQueryRequest(kind: .workoutSummary, interval: interval, limit: 40)
        )
        try await MainActor.run { try HealthQueryIntentAccess.requireProtectedData() }
        return result.records.filter { Self.hasSourcePrefix($0.id) }
            .map { HealthWorkoutEntity(id: $0.id, name: $0.name) }
    }

    private static func hasSourcePrefix(_ id: String) -> Bool {
        id.hasPrefix("app:") || id.hasPrefix("healthkit:")
    }
}

struct OpenHealthWorkoutIntent: OpenIntent, TargetContentProvidingIntent {
    static let title: LocalizedStringResource = "Open Health Workout"
    static let description = IntentDescription("Open a workout record in DUNE.")
    static var authenticationPolicy: IntentAuthenticationPolicy { .requiresLocalDeviceAuthentication }
    static var allowedExecutionTargets: ExecutionTargets { .main }

    @Parameter(title: "Workout") var target: HealthWorkoutEntity

    static var parameterSummary: some ParameterSummary { Summary("Open \(\.$target) in DUNE") }

    func perform() async throws -> some IntentResult {
        let matches = try await HealthWorkoutEntityQuery().entities(for: [target.id])
        guard matches.first != nil else { throw DUNEAppIntentError.itemNotFound }
        await HealthQueryNavigation.shared.open(
            request: HealthQueryRequest(
                kind: .latestWorkout,
                interval: HealthQueryPeriod.last365Days.interval(endingAt: Date()),
                workoutID: target.id
            )
        )
        return .result()
    }
}

#if compiler(>=6.4)
@available(iOS 27.0, *)
@AppIntent(schema: .system.searchInApp)
struct SearchHealthInAppIntent: ShowInAppSearchResultsIntent {
    static var searchScopes: [StringSearchScope] { [.general] }
    static var authenticationPolicy: IntentAuthenticationPolicy { .requiresLocalDeviceAuthentication }
    static var allowedExecutionTargets: ExecutionTargets { .main }

    var criteria: StringSearchCriteria

    func perform() async throws -> some IntentResult {
        try await MainActor.run { try HealthQueryIntentAccess.requireProtectedData() }
        await HealthQueryNavigation.shared.open(
            request: HealthQueryRequest(kind: .memoSearch, searchText: criteria.term)
        )
        return .result()
    }
}
#endif
