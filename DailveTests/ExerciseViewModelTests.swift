import Foundation
import Testing
@testable import Dailve

@Suite("ExerciseViewModel")
@MainActor
struct ExerciseViewModelTests {
    @Test("createValidatedRecord returns nil without exercise type")
    func missingType() {
        let vm = ExerciseViewModel()
        vm.newExerciseType = ""

        let record = vm.createValidatedRecord()
        #expect(record == nil)
    }

    @Test("createValidatedRecord succeeds with valid data")
    func validRecord() {
        let vm = ExerciseViewModel()
        vm.newExerciseType = "Running"
        vm.newDuration = 30 * 60
        vm.newCalories = "300"

        let record = vm.createValidatedRecord()
        #expect(record != nil)
        #expect(record?.exerciseType == "Running")
        #expect(record?.calories == 300)
    }

    @Test("createValidatedRecord rejects invalid calories")
    func invalidCalories() {
        let vm = ExerciseViewModel()
        vm.newExerciseType = "Running"
        vm.newCalories = "15000"

        let record = vm.createValidatedRecord()
        #expect(record == nil)
        #expect(vm.validationError != nil)
    }

    @Test("createValidatedRecord rejects invalid distance")
    func invalidDistance() {
        let vm = ExerciseViewModel()
        vm.newExerciseType = "Running"
        vm.newDistance = "999999"

        let record = vm.createValidatedRecord()
        #expect(record == nil)
        #expect(vm.validationError != nil)
    }

    @Test("isSaving prevents duplicate creation")
    func isSavingGuard() {
        let vm = ExerciseViewModel()
        vm.newExerciseType = "Running"
        vm.isSaving = true

        let record = vm.createValidatedRecord()
        #expect(record == nil)
    }

    @Test("Memo truncated to 500 chars")
    func memoTruncation() {
        let vm = ExerciseViewModel()
        vm.newExerciseType = "Running"
        vm.newMemo = String(repeating: "x", count: 600)

        let record = vm.createValidatedRecord()
        #expect(record?.memo.count == 500)
    }

    // MARK: - Date Selection

    @Test("createValidatedRecord uses selectedDate")
    func usesSelectedDate() {
        let vm = ExerciseViewModel()
        vm.newExerciseType = "Running"
        let pastDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        vm.selectedDate = pastDate

        let record = vm.createValidatedRecord()
        #expect(record != nil)
        #expect(record?.date == pastDate)
    }

    @Test("createValidatedRecord rejects future date")
    func rejectsFutureDate() {
        let vm = ExerciseViewModel()
        vm.newExerciseType = "Running"
        vm.selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

        let record = vm.createValidatedRecord()
        #expect(record == nil)
        #expect(vm.validationError != nil)
    }

    @Test("resetForm resets selectedDate to now")
    func resetFormResetsDate() {
        let vm = ExerciseViewModel()
        vm.selectedDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!

        let before = Date()
        vm.resetForm()
        let after = Date()

        #expect(vm.selectedDate >= before)
        #expect(vm.selectedDate <= after)
    }
}
