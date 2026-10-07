import Testing
@testable import DUNE

@Suite("Posture display transfer")
@MainActor
struct PostureDisplayTransferTests {
    @Test("A cancelled countdown cannot reset a new display's countdown")
    func staleCountdown() async {
        let model = PostureAssessmentViewModel()
        model.capturePhase = .preparing
        model.startCountdown()
        await Task.yield()
        model.stopCamera()
        model.startCountdown()
        for _ in 0..<5 { await Task.yield() }
        #expect(model.capturePhase == .countdown(3))
        model.stopCamera()
    }

    @Test("An interrupted countdown returns to preparation")
    func interruptedCountdown() {
        let model = PostureAssessmentViewModel()
        model.capturePhase = .countdown(2)
        model.stopCamera()
        #expect(model.capturePhase == .preparing)
    }

    @Test("An interrupted capture returns to preparation without error feedback")
    func interruptedCapture() {
        let model = PostureAssessmentViewModel()
        model.capturePhase = .capturing
        model.stopCamera()
        #expect(model.capturePhase == .preparing)
        #expect(model.hapticErrorCount == 0)
    }

    @Test("Stopping preview preserves an assessment result and memo")
    func preserveResult() {
        let model = PostureAssessmentViewModel()
        model.capturePhase = .result
        model.memo = "assessment note"
        model.stopCamera()
        #expect(model.capturePhase == .result)
        #expect(model.memo == "assessment note")
    }
}
