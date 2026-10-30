import Foundation
import Observation

@MainActor @Observable
final class HealthQueryViewModel {
    enum State: Equatable {
        case idle, loading, loaded(HealthQueryResult), failed(String), cancelled
    }

    private let service: any HealthQuerying
    private let assistant: any HealthQueryAssisting
    private var task: Task<Void, Never>?
    private var explanationTask: Task<Void, Never>?
    private var generation = 0
    private(set) var state: State = .idle
    private(set) var isExplaining = false
    private(set) var explanationMessage: String?

    init(service: any HealthQuerying, assistant: (any HealthQueryAssisting)? = nil) {
        self.service = service
        self.assistant = assistant ?? HealthQueryAssistant(queryService: service)
    }

    func load(_ request: HealthQueryRequest) {
        task?.cancel()
        explanationTask?.cancel()
        isExplaining = false
        explanationMessage = nil
        generation += 1
        let currentGeneration = generation
        state = .loading
        task = Task {
            do {
                let result = try await service.execute(request)
                guard !Task.isCancelled, generation == currentGeneration else { return }
                state = .loaded(result)
            } catch is CancellationError {
                guard generation == currentGeneration else { return }
                state = .cancelled
            } catch {
                guard !Task.isCancelled, generation == currentGeneration else { return }
                state = .failed(String(localized: "Could not load health data. Try again."))
            }
        }
    }

    func explainComparison() {
        guard case .loaded(let result) = state,
              result.status == .available || result.status == .partial,
              !result.sources.isEmpty,
              result.metrics.contains(where: { $0.value.isFinite && $0.comparisonValue?.isFinite == true }) else { return }
        explanationTask?.cancel()
        let currentGeneration = generation
        isExplaining = true
        explanationMessage = nil
        explanationTask = Task {
            do {
                let explained = try await assistant.explain(result, useCloud: false)
                guard !Task.isCancelled, generation == currentGeneration else { return }
                state = .loaded(explained)
                if explained.explanationStatus != .generated {
                    explanationMessage = String(localized: "Explanation is unavailable on this device.")
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, generation == currentGeneration else { return }
                explanationMessage = String(localized: "Could not explain this comparison.")
            }
            if generation == currentGeneration { isExplaining = false }
        }
    }

    func clear() {
        cancel()
        state = .idle
    }

    func cancel() {
        generation += 1
        task?.cancel()
        explanationTask?.cancel()
        task = nil
        explanationTask = nil
        isExplaining = false
        state = .cancelled
    }
}

