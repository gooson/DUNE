import Foundation
import Testing
@testable import DUNE

@Suite("HealthQueryAssistant")
@MainActor
struct HealthQueryAssistantTests {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    @Test("Unavailable model uses only exact supported fallback questions")
    func narrowFallback() async throws {
        let service = AssistantQueryStub(now: now)
        let assistant = HealthQueryAssistant(queryService: service, availabilityProvider: { false })
        let result = try await assistant.ask("최근 운동")
        #expect(result == service.result)
        #expect(service.requests.count == 1)
        let ambiguous = try await assistant.ask("최근 운동 말고 작년 체중과 비교해서 약을 추천해 줘")
        #expect(ambiguous.status == .unavailable)
        #expect(service.requests.count == 1)
    }

    @Test("Fallback never silently substitutes a prior screen context")
    func unrelatedContext() async throws {
        let service = AssistantQueryStub(now: now)
        let assistant = HealthQueryAssistant(queryService: service, availabilityProvider: { false })
        let result = try await assistant.ask("What caused this?", context: .init(kind: .condition))
        #expect(result.status == .unavailable)
        #expect(service.requests.isEmpty)
    }

    @Test("Unknown IDs and unbounded periods are rejected before querying")
    func validatePlan() {
        var plan = HealthQueryPlan(kind: "strengthSets", period: "last7Days", comparisonPeriod: "",
            workoutID: "invented", exerciseID: "", searchText: "")
        #expect(HealthQueryAssistant.validatedRequest(plan, context: nil, now: now) == nil)
        plan.workoutID = ""
        plan.period = "allTime"
        #expect(HealthQueryAssistant.validatedRequest(plan, context: nil, now: now) == nil)
        plan.period = "last7Days"
        #expect(HealthQueryAssistant.validatedRequest(plan, context: nil, now: now)?.kind == .strengthSets)
    }

    @Test("Overlapping comparison periods are rejected")
    func overlappingComparison() {
        let plan = HealthQueryPlan(kind: "metricComparison", period: "last7Days",
            comparisonPeriod: "last30Days", workoutID: "", exerciseID: "", searchText: "")
        #expect(HealthQueryAssistant.validatedRequest(plan, context: nil, now: now) == nil)
    }

    @Test("Unavailable cloud explanation preserves every original fact")
    func immutableFacts() async throws {
        let service = AssistantQueryStub(now: now)
        let assistant = HealthQueryAssistant(queryService: service, availabilityProvider: { false })
        var expected = service.result
        expected.explanationStatus = .unavailable
        #expect(try await assistant.explain(service.result, useCloud: true) == expected)
        #expect(await assistant.modelStatus(useCloud: true) == .cloudNotAuthorized)
    }

    @Test("Cancelled requests do not query data")
    func cancellation() async throws {
        let service = AssistantQueryStub(now: now)
        let assistant = HealthQueryAssistant(queryService: service, availabilityProvider: { false })
        let task = Task {
            try Task.checkCancellation()
            return try await assistant.ask("latest workout")
        }
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch is CancellationError {
            #expect(service.requests.isEmpty)
        }
    }
}

@MainActor
private final class AssistantQueryStub: HealthQuerying {
    let result: HealthQueryResult
    var requests: [HealthQueryRequest] = []
    init(now: Date) {
        result = HealthQueryResult(kind: .latestWorkout, status: .available, title: "Workout",
            generatedAt: now, interval: .init(start: now.addingTimeInterval(-86400), end: now),
            metrics: [.init(id: "duration", title: "Duration", value: 10, unit: .seconds)],
            sources: [.init(kind: .app, recordID: "source", fetchedAt: now)], spokenSummary: "Verified summary")
    }
    func execute(_ request: HealthQueryRequest) async throws -> HealthQueryResult {
        requests.append(request)
        return result
    }
}
