import Foundation
import Observation

@Observable
@MainActor
final class BodyCompositionViewModel {
    private let maxWeight = 500.0
    private let maxBodyFat = 100.0
    private let maxMuscleMass = 300.0
    private let maxMemoLength = 500

    var isShowingAddSheet = false
    var isShowingEditSheet = false
    var editingRecord: BodyCompositionRecord?

    // Form fields
    var newWeight: String = ""
    var newBodyFat: String = ""
    var newMuscleMass: String = ""
    var newMemo: String = ""
    var selectedDate: Date = Date() { didSet { validationError = nil } }
    var validationError: String?
    var isSaving = false

    func createValidatedRecord() -> BodyCompositionRecord? {
        guard !isSaving else { return nil }

        if selectedDate.isFuture {
            validationError = "Future dates are not allowed"
            return nil
        }

        guard let validated = validateInputs() else { return nil }
        isSaving = true
        defer { isSaving = false }
        return BodyCompositionRecord(
            date: selectedDate,
            weight: validated.weight,
            bodyFatPercentage: validated.bodyFat,
            muscleMass: validated.muscleMass,
            memo: String(newMemo.prefix(maxMemoLength))
        )
    }

    func applyUpdate(to record: BodyCompositionRecord) -> Bool {
        guard !isSaving else { return false }
        if selectedDate.isFuture {
            validationError = "Future dates are not allowed"
            return false
        }

        guard let validated = validateInputs() else { return false }
        record.date = selectedDate
        record.weight = validated.weight
        record.bodyFatPercentage = validated.bodyFat
        record.muscleMass = validated.muscleMass
        record.memo = String(newMemo.prefix(maxMemoLength))
        return true
    }

    private func validateInputs() -> (weight: Double?, bodyFat: Double?, muscleMass: Double?)? {
        validationError = nil

        let weight: Double? = newWeight.isEmpty ? nil : Double(newWeight)
        if !newWeight.isEmpty {
            guard let w = weight, w > 0, w < maxWeight else {
                validationError = "Weight must be between 0 and \(Int(maxWeight)) kg"
                return nil
            }
        }

        let bodyFat: Double? = newBodyFat.isEmpty ? nil : Double(newBodyFat)
        if !newBodyFat.isEmpty {
            guard let bf = bodyFat, bf >= 0, bf <= maxBodyFat else {
                validationError = "Body fat must be between 0% and \(Int(maxBodyFat))%"
                return nil
            }
        }

        let muscleMass: Double? = newMuscleMass.isEmpty ? nil : Double(newMuscleMass)
        if !newMuscleMass.isEmpty {
            guard let mm = muscleMass, mm > 0, mm < maxMuscleMass else {
                validationError = "Muscle mass must be between 0 and \(Int(maxMuscleMass)) kg"
                return nil
            }
        }

        return (weight: weight, bodyFat: bodyFat, muscleMass: muscleMass)
    }

    func startEditing(_ record: BodyCompositionRecord) {
        editingRecord = record
        newWeight = record.weight.map { String(format: "%.1f", $0) } ?? ""
        newBodyFat = record.bodyFatPercentage.map { String(format: "%.1f", $0) } ?? ""
        newMuscleMass = record.muscleMass.map { String(format: "%.1f", $0) } ?? ""
        newMemo = record.memo
        selectedDate = record.date
        isShowingEditSheet = true
    }

    func resetForm() {
        newWeight = ""
        newBodyFat = ""
        newMuscleMass = ""
        newMemo = ""
        selectedDate = Date()
        validationError = nil
        editingRecord = nil
    }
}
