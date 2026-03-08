import Foundation

/// Result from the health data Q&A service.
struct HealthDataQAReply: Sendable, Equatable {
    let text: String
    let generatedAt: Date
    let isFallback: Bool
}

/// Handles multi-turn natural language questions about recent health data.
protocol HealthDataQuestionAnswering: Sendable {
    func ask(_ question: String) async -> HealthDataQAReply
    func resetConversation() async
}
