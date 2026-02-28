import Foundation
import Testing
@testable import DUNE

@Suite("LifeViewModel")
@MainActor
struct LifeViewModelTests {

    // MARK: - createValidatedHabit

    @Test("createValidatedHabit returns habit with valid inputs")
    func validHabit() {
        let vm = LifeViewModel()
        vm.name = "Take vitamins"
        vm.selectedIconCategory = .health
        vm.selectedType = .check
        vm.frequencyType = "daily"

        let habit = vm.createValidatedHabit()
        #expect(habit != nil)
        #expect(habit?.name == "Take vitamins")
        #expect(habit?.habitType == .check)
        #expect(habit?.iconCategory == .health)
        #expect(habit?.goalValue == 1.0)
        #expect(vm.validationError == nil)
        // Correction #43: isSaving stays true until didFinishSaving
        #expect(vm.isSaving == true)
        vm.didFinishSaving()
        #expect(vm.isSaving == false)
    }

    @Test("createValidatedHabit fails for empty name")
    func emptyName() {
        let vm = LifeViewModel()
        vm.name = ""
        vm.selectedType = .check

        let habit = vm.createValidatedHabit()
        #expect(habit == nil)
        #expect(vm.validationError != nil)
        #expect(vm.validationError?.contains("name") == true)
    }

    @Test("createValidatedHabit fails for whitespace-only name")
    func whitespaceOnlyName() {
        let vm = LifeViewModel()
        vm.name = "   "
        vm.selectedType = .check

        let habit = vm.createValidatedHabit()
        #expect(habit == nil)
        #expect(vm.validationError != nil)
    }

    @Test("createValidatedHabit blocks duplicate save with isSaving")
    func isSavingGuard() {
        let vm = LifeViewModel()
        vm.name = "Test"
        vm.selectedType = .check

        _ = vm.createValidatedHabit()
        #expect(vm.isSaving == true)

        // Second call should return nil
        let second = vm.createValidatedHabit()
        #expect(second == nil)
    }

    @Test("createValidatedHabit validates duration goal > 0")
    func durationGoalZero() {
        let vm = LifeViewModel()
        vm.name = "Coding"
        vm.selectedType = .duration
        vm.goalValue = "0"

        let habit = vm.createValidatedHabit()
        #expect(habit == nil)
        #expect(vm.validationError != nil)
    }

    @Test("createValidatedHabit validates duration goal within max")
    func durationGoalOverMax() {
        let vm = LifeViewModel()
        vm.name = "Coding"
        vm.selectedType = .duration
        vm.goalValue = "2000"

        let habit = vm.createValidatedHabit()
        #expect(habit == nil)
        #expect(vm.validationError != nil)
    }

    @Test("createValidatedHabit validates count goal > 0")
    func countGoalZero() {
        let vm = LifeViewModel()
        vm.name = "Water"
        vm.selectedType = .count
        vm.goalValue = "-1"

        let habit = vm.createValidatedHabit()
        #expect(habit == nil)
        #expect(vm.validationError != nil)
    }

    @Test("createValidatedHabit creates duration habit correctly")
    func validDurationHabit() {
        let vm = LifeViewModel()
        vm.name = "Coding"
        vm.selectedIconCategory = .coding
        vm.selectedType = .duration
        vm.goalValue = "60"
        vm.goalUnit = "min"
        vm.frequencyType = "daily"

        let habit = vm.createValidatedHabit()
        #expect(habit != nil)
        #expect(habit?.habitType == .duration)
        #expect(habit?.goalValue == 60.0)
        #expect(habit?.goalUnit == "min")
        vm.didFinishSaving()
    }

    @Test("createValidatedHabit creates weekly habit correctly")
    func validWeeklyHabit() {
        let vm = LifeViewModel()
        vm.name = "Exercise"
        vm.selectedType = .check
        vm.frequencyType = "weekly"
        vm.weeklyTargetDays = 4

        let habit = vm.createValidatedHabit()
        #expect(habit != nil)
        #expect(habit?.frequency == .weekly(targetDays: 4))
        vm.didFinishSaving()
    }

    @Test("createValidatedHabit creates auto-linked habit")
    func autoLinkedHabit() {
        let vm = LifeViewModel()
        vm.name = "Daily workout"
        vm.selectedType = .check
        vm.isAutoLinked = true

        let habit = vm.createValidatedHabit()
        #expect(habit != nil)
        #expect(habit?.isAutoLinked == true)
        #expect(habit?.autoLinkSourceRaw == "exercise")
        vm.didFinishSaving()
    }

    // MARK: - didFinishSaving

    @Test("didFinishSaving resets isSaving flag")
    func didFinishSaving() {
        let vm = LifeViewModel()
        vm.name = "Test"
        _ = vm.createValidatedHabit()
        #expect(vm.isSaving == true)

        vm.didFinishSaving()
        #expect(vm.isSaving == false)
    }

    // MARK: - resetForm

    @Test("resetForm clears all fields")
    func resetForm() {
        let vm = LifeViewModel()
        vm.name = "Custom habit"
        vm.selectedIconCategory = .coding
        vm.selectedType = .duration
        vm.goalValue = "30"
        vm.goalUnit = "min"
        vm.frequencyType = "weekly"
        vm.weeklyTargetDays = 5
        vm.isAutoLinked = true
        vm.validationError = "Some error"

        vm.resetForm()

        #expect(vm.name == "")
        #expect(vm.selectedIconCategory == .health)
        #expect(vm.selectedType == .check)
        #expect(vm.goalValue == "1")
        #expect(vm.goalUnit == "")
        #expect(vm.frequencyType == "daily")
        #expect(vm.weeklyTargetDays == 3)
        #expect(vm.isAutoLinked == false)
        #expect(vm.validationError == nil)
    }

    // MARK: - Name validation clears error

    @Test("setting name clears validationError")
    func nameSetClearsError() {
        let vm = LifeViewModel()
        vm.validationError = "Some error"
        vm.name = "New name"
        #expect(vm.validationError == nil)
    }

    // MARK: - Name truncation

    @Test("createValidatedHabit truncates long names")
    func nameTruncation() {
        let vm = LifeViewModel()
        vm.name = String(repeating: "A", count: 100)
        vm.selectedType = .check

        let habit = vm.createValidatedHabit()
        #expect(habit != nil)
        #expect(habit!.name.count == 50)
        vm.didFinishSaving()
    }
}
