import Foundation

/// Shares verified, read-only facts between the app, App Intents, and model tools.
@MainActor
protocol HealthQuerying: Sendable {
    func execute(_ request: HealthQueryRequest) async throws -> HealthQueryResult
}

protocol HealthQueryAssisting: Sendable {
    func ask(_ question: String, context: HealthQueryRequest?) async throws -> HealthQueryResult
    func explain(_ result: HealthQueryResult, useCloud: Bool) async throws -> HealthQueryResult
}
