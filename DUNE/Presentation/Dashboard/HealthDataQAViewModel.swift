import Foundation
import Observation

struct HealthDataQAMessage: Identifiable, Sendable, Equatable {
    enum Role: Sendable, Equatable {
        case assistant
        case user
    }

    let id = UUID()
    let role: Role
    let text: String
    let isFallback: Bool
    let createdAt: Date
}

@Observable
@MainActor
final class HealthDataQAViewModel {
    var messages: [HealthDataQAMessage] = []
    var draft = ""
    var isSending = false

    let isAvailable: Bool

    private let service: any HealthDataQuestionAnswering

    private enum Labels {
        static let sleepPrompt = String(localized: "How has my sleep looked this week?")
        static let recoveryPrompt = String(localized: "Why is my condition score low today?")
        static let workoutPrompt = String(localized: "What workouts have I done recently?")
    }

    init(
        service: any HealthDataQuestionAnswering,
        isAvailable: Bool = HealthDataQAService.isAvailable
    ) {
        self.service = service
        self.isAvailable = isAvailable
    }

    var suggestedPrompts: [String] {
        [Labels.sleepPrompt, Labels.recoveryPrompt, Labels.workoutPrompt]
    }

    var canSend: Bool {
        isAvailable && !isSending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func sendCurrentDraft() async {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isAvailable, !isSending, !question.isEmpty else { return }
        draft = ""
        await send(prompt: question)
    }

    func send(prompt: String) async {
        guard !isSending else { return }
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }

        isSending = true
        messages.append(
            HealthDataQAMessage(
                role: .user,
                text: trimmedPrompt,
                isFallback: false,
                createdAt: Date()
            )
        )

        let reply = await service.ask(trimmedPrompt)
        messages.append(
            HealthDataQAMessage(
                role: .assistant,
                text: reply.text,
                isFallback: reply.isFallback,
                createdAt: reply.generatedAt
            )
        )
        isSending = false
    }

    func resetConversation() async {
        messages = []
        draft = ""
        isSending = false
        await service.resetConversation()
    }
}
