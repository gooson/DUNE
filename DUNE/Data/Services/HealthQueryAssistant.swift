import Foundation
import FoundationModels

enum HealthQueryPreferences {
    static let cloudAnalysisEnabledKey = "healthQuery.cloudAnalysisEnabled"
    static let semanticSearchEnabledKey = "healthQuery.semanticSearchEnabled"
}

enum HealthQueryModelStatus: Sendable, Equatable {
    case onDevice, unavailable, unsupportedLanguage, cloudNotAuthorized
}

/// Each invocation owns its model sessions and evidence. Siri and in-app requests never share history.
actor HealthQueryAssistant: HealthQueryAssisting {
    @MainActor static let shared = HealthQueryAssistant(queryService: HealthQueryService.shared)

    private let queryService: any HealthQuerying
    private let availabilityProvider: @Sendable () -> Bool
    private let localeProvider: @Sendable () -> Locale
    private let nowProvider: @Sendable () -> Date

    init(queryService: any HealthQuerying,
         availabilityProvider: @escaping @Sendable () -> Bool = { SystemLanguageModel.default.isAvailable },
         localeProvider: @escaping @Sendable () -> Locale = { HealthQueryLocalization.locale },
         nowProvider: @escaping @Sendable () -> Date = Date.init) {
        self.queryService = queryService
        self.availabilityProvider = availabilityProvider
        self.localeProvider = localeProvider
        self.nowProvider = nowProvider
    }

    func modelStatus(useCloud: Bool = false) -> HealthQueryModelStatus {
        // This app has no verified managed PCC entitlement. Opt-in alone cannot grant access.
        if useCloud { return .cloudNotAuthorized }
        guard availabilityProvider() else { return .unavailable }
        guard SystemLanguageModel.default.supportsLocale(localeProvider()) else { return .unsupportedLanguage }
        return .onDevice
    }

    func ask(_ question: String, context: HealthQueryRequest? = nil) async throws -> HealthQueryResult {
        try Task.checkCancellation()
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 500 else { return unavailable(kind: context?.kind ?? .report) }
        if modelStatus() != .onDevice {
            // Exact example phrases only: arbitrary questions are never guessed by keyword matching.
            guard let request = Self.fallbackRequest(text, now: nowProvider()) else {
                return unavailable(kind: context?.kind ?? .report)
            }
            return try await queryService.execute(request)
        }
        let planning = LanguageModelSession(instructions: """
        Translate the user's read-only health question into a plan. Never answer the health question yourself.
        Supported kinds: \(HealthQueryKind.allCases.map(\.rawValue).joined(separator: ", ")).
        Supported periods: \(HealthQueryPeriod.allCases.map(\.rawValue).joined(separator: ", ")).
        Use unsupported for medical advice, unknown facts, unsupported time ranges or ambiguous requests.
        Only reuse supplied context IDs if the user explicitly refers to that workout/exercise.
        Never invent IDs. Use empty strings for absent IDs, comparison period, or search text.
        Set period to context only when referring to the supplied context's period.
        Default to last30Days for latest records, today for condition and yesterday for sleep.
        Context kind: \(context?.kind.rawValue ?? "none"); workout ID: \(context?.workoutID ?? "none");
        exercise ID: \(context?.exerciseID ?? "none"); interval: \(String(describing: context?.interval)).
        """)
        let plan = try await planning.respond(to: text, generating: HealthQueryPlan.self).content
        try Task.checkCancellation()
        guard let request = Self.validatedRequest(plan, context: context, now: nowProvider()) else {
            return unavailable(kind: context?.kind ?? .report)
        }
        #if compiler(>=6.4)
        if #available(iOS 27.0, macOS 27.0, visionOS 27.0, *) {
            let evidence = HealthQueryEvidence(service: queryService, request: request)
            let session = LanguageModelSession(profile: HealthQueryEvidenceProfile(evidence: evidence))
            _ = try await session.respond(to: "Fetch the validated request, then acknowledge completion.")
            try Task.checkCancellation()
            guard let result = await evidence.result else { return unavailable(kind: request.kind) }
            return result
        }
        #endif
        return try await queryService.execute(request)
    }

    func explain(_ result: HealthQueryResult, useCloud: Bool = false) async throws -> HealthQueryResult {
        try Task.checkCancellation()
        var answer = result
        guard modelStatus(useCloud: useCloud) == .onDevice,
              result.status == .available || result.status == .partial,
              !result.sources.isEmpty else {
            answer.explanationStatus = .unavailable
            return answer
        }
        // The model selects an existing comparison; application code verifies and renders its meaning.
        let comparable = result.metrics.filter {
            $0.value.isFinite && ($0.comparisonValue?.isFinite == true)
        }
        guard !comparable.isEmpty else {
            answer.explanationStatus = .unavailable
            return answer
        }
        let facts = comparable.compactMap { metric -> String? in
            guard let previous = metric.comparisonValue else { return nil }
            return "\(metric.id): current=\(metric.value), previous=\(previous)"
        }.joined(separator: "\n")
        let session = LanguageModelSession(instructions: "Select one metric ID from the supplied verified comparisons. Do not generate any values, dates, advice or prose.")
        let selection = try await session.respond(to: facts, generating: HealthQueryExplanationSelection.self).content
        try Task.checkCancellation()
        guard let metric = comparable.first(where: { $0.id == selection.metricID }),
              let previous = metric.comparisonValue else {
            answer.explanationStatus = .unavailable
            return answer
        }
        if metric.value > previous {
            answer.explanation = String(localized: "The selected metric is higher than in the comparison period.", locale: HealthQueryLocalization.locale)
        } else if metric.value < previous {
            answer.explanation = String(localized: "The selected metric is lower than in the comparison period.", locale: HealthQueryLocalization.locale)
        } else {
            answer.explanation = String(localized: "The selected metric is unchanged from the comparison period.", locale: HealthQueryLocalization.locale)
        }
        answer.explanation = metric.title + ": " + (answer.explanation ?? "")
        answer.explanationStatus = .generated
        return answer
    }

    private func unavailable(kind: HealthQueryKind) -> HealthQueryResult {
        let now = nowProvider()
        return HealthQueryResult(kind: kind, status: .unavailable,
            title: String(localized: "Health Question", locale: HealthQueryLocalization.locale), generatedAt: now,
            interval: HealthQueryPeriod.today.interval(endingAt: now),
            spokenSummary: String(localized: "Choose a health topic and period to view your records. This question could not be interpreted.", locale: HealthQueryLocalization.locale),
            explanationStatus: .unavailable, isComplete: false)
    }

    static func fallbackRequest(_ question: String, now: Date) -> HealthQueryRequest? {
        let kind: HealthQueryKind
        let period: HealthQueryPeriod
        switch question.lowercased() {
        case "latest workout", "최근 운동", "最近のワークアウト":
            kind = .latestWorkout; period = .last30Days
        case "latest body measurements", "최근 신체 기록", "最近の身体測定":
            kind = .latestBody; period = .last30Days
        case "today's condition", "오늘 컨디션", "今日のコンディション":
            kind = .condition; period = .today
        case "last night's sleep", "어젯밤 수면", "昨夜の睡眠":
            kind = .sleep; period = .yesterday
        default: return nil
        }
        return HealthQueryRequest(kind: kind, interval: period.interval(endingAt: now))
    }

    static func validatedRequest(_ plan: HealthQueryPlan, context: HealthQueryRequest?, now: Date) -> HealthQueryRequest? {
        guard let kind = HealthQueryKind(rawValue: plan.kind),
              plan.searchText.count <= 500,
              plan.workoutID.isEmpty || plan.workoutID == context?.workoutID,
              plan.exerciseID.isEmpty || plan.exerciseID == context?.exerciseID else { return nil }
        let interval: DateInterval?
        if plan.period == "context" { interval = context?.interval }
        else { interval = HealthQueryPeriod(rawValue: plan.period)?.interval(endingAt: now) }
        guard let interval, interval.duration > 0, interval.duration <= 366 * 86400,
              interval.start.timeIntervalSince1970.isFinite, interval.end <= now else { return nil }
        let comparison = HealthQueryPeriod(rawValue: plan.comparisonPeriod)?.interval(endingAt: now)
        guard plan.comparisonPeriod.isEmpty || comparison != nil else { return nil }
        if kind == .metricComparison || kind == .workoutComparison {
            guard let comparison, comparison.end <= interval.start || interval.end <= comparison.start else { return nil }
        }
        return HealthQueryRequest(kind: kind, interval: interval, comparisonInterval: comparison,
            workoutID: plan.workoutID.isEmpty ? nil : plan.workoutID,
            exerciseID: plan.exerciseID.isEmpty ? nil : plan.exerciseID,
            searchText: plan.searchText.isEmpty ? nil : plan.searchText, limit: 20)
    }
}

@Generable
struct HealthQueryPlan {
    @Guide(description: "A supported query kind raw value, or unsupported") var kind: String
    @Guide(description: "A supported period raw value, or context") var period: String
    var comparisonPeriod: String
    var workoutID: String
    var exerciseID: String
    var searchText: String
}

@Generable
private struct HealthQueryExplanationSelection {
    var metricID: String
}

#if compiler(>=6.4)
@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
private extension SessionPropertyValues {
    @SessionPropertyEntry var healthEvidenceFetched: Bool = false
}

private actor HealthQueryEvidence {
    let service: any HealthQuerying
    let request: HealthQueryRequest
    private(set) var result: HealthQueryResult?
    init(service: any HealthQuerying, request: HealthQueryRequest) {
        self.service = service
        self.request = request
    }
    func fetch() async throws -> HealthQueryResult {
        try Task.checkCancellation()
        if let result { return result }
        let fetched = try await service.execute(request)
        try Task.checkCancellation()
        result = fetched
        return fetched
    }
}

@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
private struct HealthQueryEvidenceTool: Tool {
    let name = "fetchVerifiedHealthQuery"
    let description = "Execute the validated read-only request and retrieve exact source-backed facts."
    let evidence: HealthQueryEvidence
    @SessionProperty(\.healthEvidenceFetched) var fetched
    @Generable struct Arguments { var acknowledge: Bool }
    func call(arguments: Arguments) async throws -> String {
        let result = try await evidence.fetch()
        fetched = true
        // Do not send record notes, names, or measurements back to a second model unnecessarily.
        return "Query finished. Status: \(result.status.rawValue). The application retains the exact result."
    }
}

@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
private struct HealthQueryEvidenceProfile: LanguageModelSession.DynamicProfile {
    let evidence: HealthQueryEvidence
    @SessionProperty(\.healthEvidenceFetched) var fetched
    var body: some LanguageModelSession.DynamicProfile {
        if fetched {
            LanguageModelSession.Profile {
                Instructions("Acknowledge completion. Do not provide health facts.")
            }.toolCallingMode(.disallowed).maximumResponseTokens(32)
        } else {
            LanguageModelSession.Profile {
                Instructions("Call the read-only tool once to retrieve the validated request.")
                HealthQueryEvidenceTool(evidence: evidence)
            }.toolCallingMode(.required).maximumResponseTokens(128)
        }
    }
}
#endif
