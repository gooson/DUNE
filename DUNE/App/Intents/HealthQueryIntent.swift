import AppIntents
import Foundation
import SwiftUI
import UIKit

enum HealthQueryIntentKind: String, AppEnum, CaseIterable {
    case latestWorkout, workoutSummary, strengthSets, personalRecord
    case cardioDetail, latestBody, bodyTrend, sleep, condition
    case metricComparison, workoutComparison, memoSearch, report, longAnalysis

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Health Information")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .latestWorkout: "Latest Workout", .workoutSummary: "Workout Summary",
        .strengthSets: "Completed Strength Sets", .personalRecord: "Personal Record",
        .cardioDetail: "Cardio Detail", .latestBody: "Latest Body Measurements",
        .bodyTrend: "Body Changes", .sleep: "Sleep", .condition: "Condition",
        .metricComparison: "Health Comparison", .workoutComparison: "Workout Comparison",
        .memoSearch: "Workout Notes", .report: "Workout Report",
        .longAnalysis: "Detailed Health Analysis"
    ]

    var queryKind: HealthQueryKind { HealthQueryKind(rawValue: rawValue)! }
}

enum HealthQueryIntentPeriod: String, AppEnum, CaseIterable {
    case today, yesterday, thisWeek, lastWeek, thisMonth, lastMonth
    case last7Days, last30Days, last90Days, last365Days

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Time Period")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .today: "Today", .yesterday: "Yesterday", .thisWeek: "This Week",
        .lastWeek: "Last Week", .thisMonth: "This Month", .lastMonth: "Last Month",
        .last7Days: "Last 7 Days", .last30Days: "Last 30 Days",
        .last90Days: "Last 90 Days", .last365Days: "Last 365 Days"
    ]

    var queryPeriod: HealthQueryPeriod { HealthQueryPeriod(rawValue: rawValue)! }
}

/// A transient Shortcuts value; unavailable after the in-memory result expires.
struct HealthQueryAnswerEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Health Query Answer")
    static let defaultQuery = HealthQueryAnswerEntityQuery()

    let id: String
    @Property(title: "Title") var title: String
    @Property(title: "Summary") var summary: String
    @Property(title: "Status") var status: String
    @Property(title: "Source Count") var sourceCount: Int
    @Property(title: "Measurement Count") var measurementCount: Int

    init(id: String, title: String, summary: String, status: String, sourceCount: Int, measurementCount: Int) {
        self.id = id
        self.title = title
        self.summary = summary
        self.status = status
        self.sourceCount = sourceCount
        self.measurementCount = measurementCount
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(summary)")
    }
}

struct HealthQueryAnswerEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [HealthQueryAnswerEntity] {
        try await MainActor.run {
            try HealthQueryIntentAccess.requireProtectedData()
            return identifiers.compactMap { HealthQueryIntentState.shared.answer(for: $0) }
        }
    }

    func suggestedEntities() async throws -> [HealthQueryAnswerEntity] { [] }
}

@MainActor
final class HealthQueryIntentState {
    static let shared = HealthQueryIntentState()
    private var answers: [String: (HealthQueryAnswerEntity, HealthQueryResult)] = [:]
    private var order: [String] = []
    private var protectedDataObserver: NSObjectProtocol?

    init() {
        protectedDataObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in HealthQueryIntentState.shared.clear() }
        }
    }

    func retain(_ result: HealthQueryResult) -> HealthQueryAnswerEntity {
        let id = UUID().uuidString
        let answer = HealthQueryAnswerEntity(
            id: id, title: result.title, summary: result.spokenSummary,
            status: result.status.rawValue, sourceCount: result.sources.count,
            measurementCount: result.metrics.count
        )
        answers[id] = (answer, result)
        order.append(id)
        if order.count > 8 { answers.removeValue(forKey: order.removeFirst()) }
        return answer
    }

    func answer(for id: String) -> HealthQueryAnswerEntity? { answers[id]?.0 }
    func result(for id: String) -> HealthQueryResult? { answers[id]?.1 }

    func clear() {
        answers.removeAll()
        order.removeAll()
    }
}

enum HealthQueryIntentAccess {
    @MainActor static func requireProtectedData() throws {
        guard UIApplication.shared.isProtectedDataAvailable else { throw HealthQueryIntentError.locked }
    }
}

enum HealthQueryIntentError: LocalizedError {
    case locked

    var errorDescription: String? {
        switch self {
        case .locked: String(localized: "Unlock your device to view health information.")
        }
    }
}

struct QueryHealthInformationIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Health Information"
    static let description = IntentDescription("Read verified health and workout information from DUNE.")
    static var authenticationPolicy: IntentAuthenticationPolicy { .requiresLocalDeviceAuthentication }
    static var allowedExecutionTargets: ExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }

    @Parameter(title: "Information") var information: HealthQueryIntentKind
    @Parameter(title: "Period") var period: HealthQueryIntentPeriod?
    @Parameter(title: "Comparison Period") var comparisonPeriod: HealthQueryIntentPeriod?
    @Parameter(title: "Exercise") var exercise: HealthExerciseEntity?
    @Parameter(title: "Workout") var workout: HealthWorkoutEntity?
    @Parameter(title: "Search Text") var searchText: String?

    init() {}

    init(_ information: HealthQueryIntentKind) {
        self.information = information
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Get \(\.$information) in DUNE") {
            \.$period
            \.$comparisonPeriod
            \.$exercise
            \.$workout
            \.$searchText
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<HealthQueryAnswerEntity> & ProvidesDialog & ShowsSnippetIntent {
        try await MainActor.run { try HealthQueryIntentAccess.requireProtectedData() }
        let request = makeRequest()
        let locale = intentLocale
        let result: HealthQueryResult
#if compiler(>=6.4)
        if #available(iOS 27.0, *), request.kind == .longAnalysis {
            progress.totalUnitCount = 1
            result = try await performBackgroundTask {
                try await HealthQueryLocalization.$locale.withValue(locale) {
                    try await HealthQueryService.shared.execute(request)
                }
            }
            progress.completedUnitCount = 1
        } else {
            result = try await HealthQueryLocalization.$locale.withValue(locale) {
                try await HealthQueryService.shared.execute(request)
            }
        }
#else
        result = try await HealthQueryLocalization.$locale.withValue(locale) {
            try await HealthQueryService.shared.execute(request)
        }
#endif
        try Task.checkCancellation()
        try await MainActor.run { try HealthQueryIntentAccess.requireProtectedData() }
        let answer = await MainActor.run { HealthQueryIntentState.shared.retain(result) }
        var snippet = HealthQuerySnippetIntent()
        snippet.answerID = answer.id
        return .result(value: answer, dialog: healthQueryDialog(result), snippetIntent: snippet)
    }

    private var intentLocale: Locale {
#if compiler(>=6.4)
        if #available(iOS 27.0, *) { return systemContext.locale }
#endif
        return .current
    }

    func makeRequest(now: Date = Date(), calendar: Calendar = .current) -> HealthQueryRequest {
        HealthQueryRequest(
            kind: information.queryKind,
            interval: period?.queryPeriod.interval(endingAt: now, calendar: calendar),
            comparisonInterval: comparisonPeriod?.queryPeriod.interval(endingAt: now, calendar: calendar),
            workoutID: workout?.id,
            exerciseID: exercise?.id,
            searchText: searchText?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

struct AskDUNEHealthIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask DUNE About Health"
    static let description = IntentDescription("Ask a question about your available health and workout records.")
    static var authenticationPolicy: IntentAuthenticationPolicy { .requiresLocalDeviceAuthentication }
    static var allowedExecutionTargets: ExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }

    @Parameter(title: "Question") var question: String

    static var parameterSummary: some ParameterSummary { Summary("Ask DUNE \(\.$question)") }

    func perform() async throws -> some IntentResult & ReturnsValue<HealthQueryAnswerEntity> & ProvidesDialog & ShowsSnippetIntent {
        try await MainActor.run { try HealthQueryIntentAccess.requireProtectedData() }
        try Task.checkCancellation()
        let askedQuestion = question
        let locale = intentLocale
#if compiler(>=6.4)
        if #available(iOS 27.0, *) { progress.totalUnitCount = 1 }
#endif
        let result: HealthQueryResult
#if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            result = try await performBackgroundTask {
                try await HealthQueryLocalization.$locale.withValue(locale) {
                    try await HealthQueryAssistant.shared.ask(askedQuestion, context: nil)
                }
            }
        } else {
            result = try await HealthQueryLocalization.$locale.withValue(locale) {
                try await HealthQueryAssistant.shared.ask(askedQuestion, context: nil)
            }
        }
#else
        result = try await HealthQueryLocalization.$locale.withValue(locale) {
            try await HealthQueryAssistant.shared.ask(askedQuestion, context: nil)
        }
#endif
        try Task.checkCancellation()
#if compiler(>=6.4)
        if #available(iOS 27.0, *) { progress.completedUnitCount = 1 }
#endif
        try await MainActor.run { try HealthQueryIntentAccess.requireProtectedData() }
        let answer = await MainActor.run { HealthQueryIntentState.shared.retain(result) }
        var snippet = HealthQuerySnippetIntent()
        snippet.answerID = answer.id
        return .result(value: answer, dialog: healthQueryDialog(result), snippetIntent: snippet)
    }

    private var intentLocale: Locale {
#if compiler(>=6.4)
        if #available(iOS 27.0, *) { return systemContext.locale }
#endif
        return .current
    }
}

private func healthQueryDialog(_ result: HealthQueryResult) -> IntentDialog {
    IntentDialog(
        full: LocalizedStringResource(stringLiteral: result.spokenSummary),
        supporting: LocalizedStringResource(stringLiteral: result.spokenSummary)
    )
}

struct HealthQuerySnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "Health Information Result"
    static var isDiscoverable: Bool { false }
    static var authenticationPolicy: IntentAuthenticationPolicy { .requiresLocalDeviceAuthentication }
    static var allowedExecutionTargets: ExecutionTargets { .main }
    @Parameter(title: "Answer ID") var answerID: String

    func perform() async throws -> some IntentResult & ShowsSnippetView {
        try await MainActor.run { try HealthQueryIntentAccess.requireProtectedData() }
        guard let result = await MainActor.run(body: { HealthQueryIntentState.shared.result(for: answerID) }) else {
            throw DUNEAppIntentError.itemNotFound
        }
        return await makeSnippet(result)
    }

    @MainActor
    private func makeSnippet(_ result: HealthQueryResult) -> some IntentResult & ShowsSnippetView {
        .result(view: HealthQuerySnippetView(result: result))
    }
}

#if compiler(>=6.4)
@available(iOS 27.0, *)
extension AskDUNEHealthIntent: LongRunningIntent {}

@available(iOS 27.0, *)
extension QueryHealthInformationIntent: LongRunningIntent {}
#endif
