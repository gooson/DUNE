import Foundation
import Testing
@testable import DUNE

@Suite("BodyCompositionViewModel")
@MainActor
struct BodyCompositionViewModelTests {
    @Test("createValidatedRecord returns record with valid inputs")
    func validRecord() {
        let vm = BodyCompositionViewModel()
        vm.newWeight = "70.5"
        vm.newBodyFat = "15.0"
        vm.newMuscleMass = "30.0"
        vm.newMemo = "Test"

        let record = vm.createValidatedRecord()
        #expect(record != nil)
        #expect(record?.weight == 70.5)
        #expect(record?.bodyFatPercentage == 15.0)
        #expect(record?.muscleMass == 30.0)
        #expect(vm.validationError == nil)
    }

    @Test("createValidatedRecord returns nil for invalid weight")
    func invalidWeight() {
        let vm = BodyCompositionViewModel()
        vm.newWeight = "600"

        let record = vm.createValidatedRecord()
        #expect(record == nil)
        #expect(vm.validationError != nil)
    }

    @Test("createValidatedRecord returns nil for invalid body fat")
    func invalidBodyFat() {
        let vm = BodyCompositionViewModel()
        vm.newBodyFat = "101"

        let record = vm.createValidatedRecord()
        #expect(record == nil)
        #expect(vm.validationError != nil)
    }

    @Test("createValidatedRecord returns nil for invalid muscle mass")
    func invalidMuscleMass() {
        let vm = BodyCompositionViewModel()
        vm.newMuscleMass = "350"

        let record = vm.createValidatedRecord()
        #expect(record == nil)
        #expect(vm.validationError != nil)
    }

    @Test("createValidatedRecord allows empty optional fields")
    func emptyOptionalFields() {
        let vm = BodyCompositionViewModel()
        // All fields empty is valid (all optional)
        let record = vm.createValidatedRecord()
        #expect(record != nil)
        #expect(record?.weight == nil)
    }

    @Test("Memo is truncated to 500 characters")
    func memoTruncation() {
        let vm = BodyCompositionViewModel()
        vm.newMemo = String(repeating: "a", count: 600)

        let record = vm.createValidatedRecord()
        #expect(record != nil)
        #expect(record?.memo.count == 500)
    }

    @Test("isSaving prevents duplicate creation")
    func isSavingGuard() {
        let vm = BodyCompositionViewModel()
        vm.isSaving = true

        let record = vm.createValidatedRecord()
        #expect(record == nil)
    }

    @Test("resetForm clears all fields")
    func resetForm() {
        let vm = BodyCompositionViewModel()
        vm.newWeight = "70"
        vm.newBodyFat = "15"
        vm.newMuscleMass = "30"
        vm.newMemo = "test"
        vm.validationError = "error"

        vm.resetForm()
        #expect(vm.newWeight == "")
        #expect(vm.newBodyFat == "")
        #expect(vm.newMuscleMass == "")
        #expect(vm.newMemo == "")
        #expect(vm.validationError == nil)
    }

    // MARK: - Date Selection

    @Test("createValidatedRecord uses selectedDate")
    func usesSelectedDate() {
        let vm = BodyCompositionViewModel()
        vm.newWeight = "70.0"
        let pastDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        vm.selectedDate = pastDate

        let record = vm.createValidatedRecord()
        #expect(record != nil)
        #expect(record?.date == pastDate)
    }

    @Test("createValidatedRecord rejects future date")
    func rejectsFutureDate() {
        let vm = BodyCompositionViewModel()
        vm.newWeight = "70.0"
        vm.selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

        let record = vm.createValidatedRecord()
        #expect(record == nil)
        #expect(vm.validationError != nil)
    }

    @Test("resetForm resets selectedDate to now")
    func resetFormResetsDate() {
        let vm = BodyCompositionViewModel()
        vm.selectedDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!

        let before = Date()
        vm.resetForm()
        let after = Date()

        #expect(vm.selectedDate >= before)
        #expect(vm.selectedDate <= after)
    }

    @Test("startEditing restores record date")
    func startEditingRestoresDate() {
        let vm = BodyCompositionViewModel()
        let record = BodyCompositionRecord(
            date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!,
            weight: 72.0
        )
        vm.startEditing(record)
        #expect(vm.selectedDate == record.date)
        #expect(vm.newWeight == "72.0")
    }

    // MARK: - HealthKit + Manual Merge

    @Test("allItems merges and sorts by date descending")
    func allItemsMerge() {
        let vm = BodyCompositionViewModel()
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!

        // Simulate HealthKit items
        vm.healthKitItems = [
            BodyCompositionListItem(
                id: "hk-1",
                date: yesterday,
                weight: 68.0,
                bodyFatPercentage: nil,
                muscleMass: nil,
                memo: "",
                source: .healthKit
            )
        ]

        let manualRecord = BodyCompositionRecord(date: now, weight: 70.0)
        let items = vm.allItems(manualRecords: [manualRecord])

        #expect(items.count == 2)
        #expect(items.first?.source == .manual) // today manual is more recent
        #expect(items.last?.source == .healthKit)
    }

    @Test("latestValues returns first item")
    func latestValues() {
        let vm = BodyCompositionViewModel()
        let record = BodyCompositionRecord(date: Date(), weight: 70.0)
        let latest = vm.latestValues(manualRecords: [record])
        #expect(latest != nil)
        #expect(latest?.weight == 70.0)
    }
}
