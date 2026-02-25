import Foundation
import Testing
@testable import DUNE

@Suite("InjuryViewModel")
@MainActor
struct InjuryViewModelTests {

    // MARK: - createValidatedRecord

    @Test("createValidatedRecord returns record with valid inputs")
    func validRecord() {
        let vm = InjuryViewModel()
        vm.selectedBodyPart = .knee
        vm.selectedSide = .left
        vm.selectedSeverity = .moderate
        vm.startDate = Date()
        vm.endDate = nil
        vm.memo = "Running injury"

        let record = vm.createValidatedRecord()
        #expect(record != nil)
        #expect(record?.bodyPart == .knee)
        #expect(record?.bodySide == .left)
        #expect(record?.severity == .moderate)
        #expect(record?.isActive == true)
        #expect(record?.memo == "Running injury")
        #expect(vm.validationError == nil)
        // Correction #43: isSaving stays true until didFinishSaving
        #expect(vm.isSaving == true)
        vm.didFinishSaving()
        #expect(vm.isSaving == false)
    }

    @Test("createValidatedRecord fails for future start date")
    func futureStartDate() {
        let vm = InjuryViewModel()
        vm.selectedBodyPart = .knee
        vm.startDate = Date().addingTimeInterval(86400 * 2)

        let record = vm.createValidatedRecord()
        #expect(record == nil)
        #expect(vm.validationError != nil)
        #expect(vm.validationError?.contains("future") == true)
    }

    @Test("createValidatedRecord fails when end date before start date")
    func endBeforeStart() {
        let vm = InjuryViewModel()
        vm.selectedBodyPart = .ankle
        vm.startDate = Date()
        vm.endDate = Date().addingTimeInterval(-86400)

        let record = vm.createValidatedRecord()
        #expect(record == nil)
        #expect(vm.validationError != nil)
        #expect(vm.validationError?.contains("after") == true)
    }

    @Test("createValidatedRecord fails for future end date")
    func futureEndDate() {
        let vm = InjuryViewModel()
        vm.selectedBodyPart = .knee
        vm.startDate = Date()
        vm.endDate = Date().addingTimeInterval(86400 * 2)

        let record = vm.createValidatedRecord()
        #expect(record == nil)
        #expect(vm.validationError?.contains("future") == true)
    }

    @Test("createValidatedRecord fails for start date too far in the past")
    func startDateTooFarInPast() {
        let vm = InjuryViewModel()
        vm.selectedBodyPart = .knee
        vm.startDate = Calendar.current.date(byAdding: .year, value: -15, to: Date()) ?? Date()

        let record = vm.createValidatedRecord()
        #expect(record == nil)
        #expect(vm.validationError?.contains("past") == true)
    }

    @Test("createValidatedRecord auto-assigns side for lateral body part")
    func lateralAutoSide() {
        let vm = InjuryViewModel()
        vm.selectedBodyPart = .shoulder
        vm.selectedSide = nil  // lateral but no side selected
        vm.startDate = Date()

        let record = vm.createValidatedRecord()
        #expect(record != nil)
        // Should auto-assign .both for lateral parts without selection
        #expect(record?.bodySide == .both)
        vm.didFinishSaving()
    }

    @Test("createValidatedRecord clears side for non-lateral body part")
    func nonLateralClearsSide() {
        let vm = InjuryViewModel()
        vm.selectedBodyPart = .neck  // neck is not lateral
        vm.selectedSide = .left  // should be cleared
        vm.startDate = Date()

        let record = vm.createValidatedRecord()
        #expect(record != nil)
        #expect(record?.bodySide == nil)
        vm.didFinishSaving()
    }

    @Test("memo is truncated to 500 characters")
    func memoTruncation() {
        let vm = InjuryViewModel()
        vm.selectedBodyPart = .knee
        vm.startDate = Date()
        vm.memo = String(repeating: "a", count: 600)

        let record = vm.createValidatedRecord()
        #expect(record != nil)
        #expect(record?.memo.count == 500)
        vm.didFinishSaving()
    }

    @Test("isSaving prevents duplicate creation")
    func isSavingGuard() {
        let vm = InjuryViewModel()
        vm.selectedBodyPart = .knee
        vm.startDate = Date()
        vm.isSaving = true

        let record = vm.createValidatedRecord()
        #expect(record == nil)
    }

    // MARK: - applyUpdate

    @Test("applyUpdate prevents double save")
    func applyUpdateIsSavingGuard() {
        let vm = InjuryViewModel()
        vm.isSaving = true

        let record = InjuryRecord(bodyPart: .knee, bodySide: .left, severity: .minor, startDate: Date())
        let result = vm.applyUpdate(to: record)
        #expect(result == false)
    }

    // MARK: - resetForm

    @Test("resetForm clears all fields")
    func resetForm() {
        let vm = InjuryViewModel()
        vm.selectedBodyPart = .ankle
        vm.selectedSide = .right
        vm.selectedSeverity = .severe
        vm.memo = "test"
        vm.validationError = "error"

        vm.resetForm()
        #expect(vm.selectedBodyPart == .knee)  // default
        #expect(vm.selectedSide == nil)
        #expect(vm.selectedSeverity == .moderate)  // default
        #expect(vm.memo == "")
        #expect(vm.validationError == nil)
        #expect(vm.editingRecord == nil)
    }

    // MARK: - markAsRecovered

    @Test("markAsRecovered sets endDate")
    func markAsRecovered() {
        let vm = InjuryViewModel()
        let record = InjuryRecord(bodyPart: .knee, bodySide: .left, severity: .moderate, startDate: Date().addingTimeInterval(-86400 * 7))
        #expect(record.isActive == true)

        vm.markAsRecovered(record)
        #expect(record.endDate != nil)
        #expect(record.isActive == false)
    }

    @Test("markAsRecovered is blocked when isSaving")
    func markAsRecoveredWhileSaving() {
        let vm = InjuryViewModel()
        vm.isSaving = true
        let record = InjuryRecord(bodyPart: .knee, bodySide: .left, severity: .moderate, startDate: Date().addingTimeInterval(-86400 * 7))

        vm.markAsRecovered(record)
        #expect(record.endDate == nil)
        #expect(record.isActive == true)
    }

    // MARK: - startDate didSet clears validation error

    @Test("changing startDate clears validation error")
    func startDateClearsError() {
        let vm = InjuryViewModel()
        vm.validationError = "Some error"
        vm.startDate = Date()
        #expect(vm.validationError == nil)
    }
}
