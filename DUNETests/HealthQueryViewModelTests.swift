import Foundation
import Testing
@testable import DUNE

@Suite("HealthQueryViewModel")
@MainActor
struct HealthQueryViewModelTests {
    @Test("Loads the requested kind and preserves the verified result")
    func loadsResult() async {
        let service = StubHealthQueryService()
        let model = HealthQueryViewModel(service: service)
        model.load(HealthQueryRequest(kind: .sleep))
        for _ in 0..<20 {
            if case .loaded = model.state { break }
            await Task.yield()
        }
        guard case .loaded(let result) = model.state else {
            Issue.record("Expected a loaded result")
            return
        }
        #expect(result.kind == .sleep)
        #expect(result.status == .noData)
    }

    @Test("Cancellation leaves no completed result visible")
    func cancels() async {
        let model = HealthQueryViewModel(service: SuspendedHealthQueryService())
        model.load(HealthQueryRequest(kind: .longAnalysis))
        #expect(model.state == .loading)
        model.cancel()
        await Task.yield()
        #expect(model.state == .cancelled)
    }

    @Test("Cancellation after a query completes keeps its verified answer")
    func cancellationPreservesLoadedResult() async {
        let model = HealthQueryViewModel(service: StubHealthQueryService())
        model.load(HealthQueryRequest(kind: .sleep))
        for _ in 0..<20 {
            if case .loaded = model.state { break }
            await Task.yield()
        }
        guard case .loaded(let original) = model.state else {
            Issue.record("Expected a loaded result before cancellation")
            return
        }
        model.cancel()
        #expect(model.state == .loaded(original))
    }

    @Test("A failed query shows a recoverable state")
    func failure() async {
        let model = HealthQueryViewModel(service: FailingHealthQueryService())
        model.load(HealthQueryRequest(kind: .report))
        for _ in 0..<20 {
            if case .failed = model.state { break }
            await Task.yield()
        }
        guard case .failed(let message) = model.state else {
            Issue.record("Expected a failure state")
            return
        }
        #expect(!message.isEmpty)
    }

    @Test("Explains a verified comparison without replacing its measurements")
    func explainsComparison() async {
        let model = HealthQueryViewModel(service: ComparisonHealthQueryService(), assistant: StubHealthQueryAssistant())
        model.load(HealthQueryRequest(kind: .metricComparison))
        for _ in 0..<20 {
            if case .loaded = model.state { break }
            await Task.yield()
        }
        model.explainComparison()
        for _ in 0..<20 {
            if case .loaded(let result) = model.state, result.explanationStatus == .generated { break }
            await Task.yield()
        }
        guard case .loaded(let result) = model.state else {
            Issue.record("Expected a loaded comparison")
            return
        }
        #expect(result.metrics.first?.value == 12)
        #expect(result.explanationStatus == .generated)
    }
}

@MainActor private struct StubHealthQueryService: HealthQuerying {
    func execute(_ request: HealthQueryRequest) async throws -> HealthQueryResult {
        HealthQueryResult(kind: request.kind, status: .noData, title: "",
                          generatedAt: .now, interval: request.interval ?? HealthQueryPeriod.today.interval(endingAt: .now),
                          spokenSummary: "")
    }
}

@MainActor private struct SuspendedHealthQueryService: HealthQuerying {
    func execute(_ request: HealthQueryRequest) async throws -> HealthQueryResult {
        try await Task.sleep(for: .seconds(30))
        return try await StubHealthQueryService().execute(request)
    }
}

@MainActor private struct FailingHealthQueryService: HealthQuerying {
    func execute(_ request: HealthQueryRequest) async throws -> HealthQueryResult {
        throw TestFailure.failed
    }
}

private enum TestFailure: Error { case failed }

@MainActor private struct ComparisonHealthQueryService: HealthQuerying {
    func execute(_ request: HealthQueryRequest) async throws -> HealthQueryResult {
        HealthQueryResult(kind: request.kind, status: .available, title: "Comparison", generatedAt: .now,
                          interval: HealthQueryPeriod.today.interval(endingAt: .now),
                          metrics: [HealthQueryMetric(id: "count", title: "Count", value: 12,
                                                      unit: .count, comparisonValue: 10)],
                          sources: [HealthQuerySource(kind: .app, fetchedAt: .now)],
                          spokenSummary: "")
    }
}

private actor StubHealthQueryAssistant: HealthQueryAssisting {
    func ask(_ question: String, context: HealthQueryRequest?) async throws -> HealthQueryResult {
        throw TestFailure.failed
    }

    func explain(_ result: HealthQueryResult, useCloud: Bool) async throws -> HealthQueryResult {
        var explained = result
        explained.explanation = "Verified comparison"
        explained.explanationStatus = .generated
        return explained
    }
}
