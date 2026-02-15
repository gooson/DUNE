import SwiftUI

@Observable
@MainActor
final class BodyCompositionViewModel {
    var isShowingAddSheet = false
    var isShowingEditSheet = false
    var editingRecord: BodyCompositionRecord?

    // Form fields
    var newWeight: String = ""
    var newBodyFat: String = ""
    var newMuscleMass: String = ""
    var newMemo: String = ""
    var validationError: String?

    func createValidatedRecord() -> BodyCompositionRecord? {
        guard let validated = validateInputs() else { return nil }
        return BodyCompositionRecord(
            date: Date(),
            weight: validated.weight,
            bodyFatPercentage: validated.bodyFat,
            muscleMass: validated.muscleMass,
            memo: String(newMemo.prefix(500))
        )
    }

    func applyUpdate(to record: BodyCompositionRecord) -> Bool {
        guard let validated = validateInputs() else { return false }
        record.weight = validated.weight
        record.bodyFatPercentage = validated.bodyFat
        record.muscleMass = validated.muscleMass
        record.memo = String(newMemo.prefix(500))
        return true
    }

    private func validateInputs() -> (weight: Double?, bodyFat: Double?, muscleMass: Double?)? {
        validationError = nil

        let weight: Double? = newWeight.isEmpty ? nil : Double(newWeight)
        if !newWeight.isEmpty {
            guard let w = weight, w > 0, w < 500 else {
                validationError = "Weight must be between 0 and 500 kg"
                return nil
            }
        }

        let bodyFat: Double? = newBodyFat.isEmpty ? nil : Double(newBodyFat)
        if !newBodyFat.isEmpty {
            guard let bf = bodyFat, bf >= 0, bf <= 100 else {
                validationError = "Body fat must be between 0% and 100%"
                return nil
            }
        }

        let muscleMass: Double? = newMuscleMass.isEmpty ? nil : Double(newMuscleMass)
        if !newMuscleMass.isEmpty {
            guard let mm = muscleMass, mm > 0, mm < 300 else {
                validationError = "Muscle mass must be between 0 and 300 kg"
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
        isShowingEditSheet = true
    }

    func resetForm() {
        newWeight = ""
        newBodyFat = ""
        newMuscleMass = ""
        newMemo = ""
        validationError = nil
        editingRecord = nil
    }
}
