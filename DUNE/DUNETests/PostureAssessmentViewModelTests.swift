import Foundation
import Testing

@testable import DUNE

@Suite("PostureAssessmentViewModel")
@MainActor
struct PostureAssessmentViewModelTests {

    // MARK: - Initial State

    @Test("Initial state is idle with front capture type")
    func initialState() {
        let vm = PostureAssessmentViewModel()

        #expect(vm.capturePhase == .idle)
        #expect(vm.captureType == .front)
        #expect(vm.frontAssessment == nil)
        #expect(vm.sideAssessment == nil)
        #expect(vm.canSave == false)
        #expect(vm.hasBothCaptures == false)
        #expect(vm.isSaving == false)
        #expect(vm.memo == "")
    }

    // MARK: - createValidatedRecord

    @Test("createValidatedRecord returns nil when no captures exist")
    func noCaptures() {
        let vm = PostureAssessmentViewModel()

        let record = vm.createValidatedRecord()

        #expect(record == nil)
        #expect(vm.validationError != nil)
        #expect(vm.isSaving == false)
    }

    @Test("createValidatedRecord prevents double save via isSaving flag")
    func doubleSavePrevention() {
        let vm = PostureAssessmentViewModel()
        vm.isSaving = true

        let record = vm.createValidatedRecord()

        #expect(record == nil)
    }

    // MARK: - Reset

    @Test("resetAll clears all state")
    func resetAll() {
        let vm = PostureAssessmentViewModel()
        vm.memo = "some note"
        vm.validationError = "some error"
        vm.capturePhase = .result

        vm.resetAll()

        #expect(vm.captureType == .front)
        #expect(vm.frontAssessment == nil)
        #expect(vm.sideAssessment == nil)
        #expect(vm.memo == "")
        #expect(vm.validationError == nil)
        #expect(vm.isSaving == false)
        #expect(vm.capturePhase == .idle)
    }

    // MARK: - Navigation

    @Test("proceedToSideCapture switches to side type")
    func proceedToSide() {
        let vm = PostureAssessmentViewModel()

        vm.proceedToSideCapture()

        #expect(vm.captureType == .side)
        #expect(vm.capturePhase == .guiding)
    }

    @Test("retakeCurrentCapture clears front assessment when in front mode")
    func retakeFront() {
        let vm = PostureAssessmentViewModel()
        vm.captureType = .front

        vm.retakeCurrentCapture()

        #expect(vm.frontAssessment == nil)
        #expect(vm.capturePhase == .guiding)
    }

    @Test("retakeCurrentCapture clears side assessment when in side mode")
    func retakeSide() {
        let vm = PostureAssessmentViewModel()
        vm.captureType = .side

        vm.retakeCurrentCapture()

        #expect(vm.sideAssessment == nil)
        #expect(vm.capturePhase == .guiding)
    }

    // MARK: - Memo

    @Test("Memo is trimmed to 500 characters in createValidatedRecord")
    func memoTruncation() {
        let vm = PostureAssessmentViewModel()
        // Simulate having a front assessment to pass validation
        vm.frontAssessment = PostureAssessment(
            captureType: .front,
            metrics: [],
            jointPositions: [],
            bodyHeight: 1.7,
            heightEstimation: .reference,
            capturedAt: Date()
        )
        vm.memo = String(repeating: "a", count: 600)

        let record = vm.createValidatedRecord()

        #expect(record != nil)
        #expect(record!.memo.count == 500)
    }

    // MARK: - Combined Assessment

    @Test("combinedAssessment reflects current state")
    func combinedAssessment() {
        let vm = PostureAssessmentViewModel()

        let combined = vm.combinedAssessment
        #expect(combined.overallScore == 0)
        #expect(!combined.isComplete)
    }

    @Test("canSave is true with front assessment only")
    func canSaveWithFrontOnly() {
        let vm = PostureAssessmentViewModel()
        vm.frontAssessment = PostureAssessment(
            captureType: .front,
            metrics: [],
            jointPositions: [],
            bodyHeight: 1.7,
            heightEstimation: .reference,
            capturedAt: Date()
        )

        #expect(vm.canSave == true)
        #expect(vm.hasBothCaptures == false)
    }

    // MARK: - didFinishSaving

    @Test("didFinishSaving resets isSaving flag")
    func didFinishSaving() {
        let vm = PostureAssessmentViewModel()
        vm.isSaving = true

        vm.didFinishSaving()

        #expect(vm.isSaving == false)
    }
}
