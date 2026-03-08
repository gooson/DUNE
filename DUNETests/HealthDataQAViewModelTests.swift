import Foundation
import Testing
@testable import DUNE

private actor MockHealthDataQAService: HealthDataQuestionAnswering {
    private let reply: HealthDataQAReply
    private var askedQuestions: [String] = []
    private var resetCount = 0

    init(reply: HealthDataQAReply) {
        self.reply = reply
    }

    func ask(_ question: String) async -> HealthDataQAReply {
        askedQuestions.append(question)
        return reply
    }

    func resetConversation() async {
        resetCount += 1
    }

    func recordedQuestions() -> [String] { askedQuestions }
    func recordedResetCount() -> Int { resetCount }
}

private actor SuspendingHealthDataQAService: HealthDataQuestionAnswering {
    private let reply: HealthDataQAReply
    private var didStart = false
    private var startContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    init(reply: HealthDataQAReply) {
        self.reply = reply
    }

    func ask(_ question: String) async -> HealthDataQAReply {
        didStart = true
        startContinuation?.resume()
        startContinuation = nil

        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
        return reply
    }

    func resetConversation() async {}

    func waitUntilAskStarts() async {
        if didStart { return }
        await withCheckedContinuation { continuation in
            startContinuation = continuation
        }
    }

    func resume() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

@Suite("HealthDataQAViewModel")
@MainActor
struct HealthDataQAViewModelTests {
    @Test("Sending current draft appends user and assistant messages")
    func sendCurrentDraftAppendsMessages() async {
        let reply = HealthDataQAReply(
            text: "Sleep was a little short, but the trend is improving.",
            generatedAt: Date(timeIntervalSince1970: 1_741_478_400),
            isFallback: false
        )
        let service = MockHealthDataQAService(reply: reply)
        let viewModel = HealthDataQAViewModel(service: service, isAvailable: true)
        viewModel.draft = "How did I sleep?"

        await viewModel.sendCurrentDraft()

        #expect(viewModel.draft.isEmpty)
        #expect(viewModel.messages.count == 2)
        #expect(viewModel.messages[0].role == .user)
        #expect(viewModel.messages[0].text == "How did I sleep?")
        #expect(viewModel.messages[1].role == .assistant)
        #expect(viewModel.messages[1].text == reply.text)
        #expect(await service.recordedQuestions() == ["How did I sleep?"])
    }

    @Test("Second send is ignored while a response is in flight")
    func secondSendIgnoredWhileBusy() async {
        let reply = HealthDataQAReply(
            text: "Your workouts have been consistent this week.",
            generatedAt: Date(timeIntervalSince1970: 1_741_478_400),
            isFallback: false
        )
        let service = SuspendingHealthDataQAService(reply: reply)
        let viewModel = HealthDataQAViewModel(service: service, isAvailable: true)
        viewModel.draft = "First question"

        let firstSend = Task { await viewModel.sendCurrentDraft() }
        await service.waitUntilAskStarts()

        await viewModel.send(prompt: "Second question")
        #expect(viewModel.isSending)
        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages[0].text == "First question")

        await service.resume()
        await firstSend.value

        #expect(!viewModel.isSending)
        #expect(viewModel.messages.count == 2)
        #expect(viewModel.messages[1].text == reply.text)
    }

    @Test("Draft is preserved if sendCurrentDraft is called while a response is in flight")
    func draftIsPreservedWhenBusy() async {
        let reply = HealthDataQAReply(
            text: "Your workouts have been consistent this week.",
            generatedAt: Date(timeIntervalSince1970: 1_741_478_400),
            isFallback: false
        )
        let service = SuspendingHealthDataQAService(reply: reply)
        let viewModel = HealthDataQAViewModel(service: service, isAvailable: true)
        viewModel.draft = "First question"

        let firstSend = Task { await viewModel.sendCurrentDraft() }
        await service.waitUntilAskStarts()

        viewModel.draft = "Second question"
        await viewModel.sendCurrentDraft()

        #expect(viewModel.draft == "Second question")
        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages[0].text == "First question")

        await service.resume()
        await firstSend.value
    }

    @Test("Reset clears conversation and forwards reset to service")
    func resetConversationClearsMessages() async {
        let reply = HealthDataQAReply(
            text: "Your condition improved compared with earlier this week.",
            generatedAt: Date(timeIntervalSince1970: 1_741_478_400),
            isFallback: false
        )
        let service = MockHealthDataQAService(reply: reply)
        let viewModel = HealthDataQAViewModel(service: service, isAvailable: true)
        viewModel.draft = "How is my recovery?"

        await viewModel.sendCurrentDraft()
        #expect(viewModel.messages.count == 2)

        await viewModel.resetConversation()

        #expect(viewModel.messages.isEmpty)
        #expect(viewModel.draft.isEmpty)
        #expect(!viewModel.isSending)
        #expect(await service.recordedResetCount() == 1)
    }
}
