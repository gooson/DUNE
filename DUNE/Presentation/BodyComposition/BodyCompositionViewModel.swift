import Foundation
import Observation

struct BodyCompositionListItem: Identifiable {
    let id: String
    let date: Date
    let weight: Double?
    let bodyFatPercentage: Double?
    let muscleMass: Double?
    let memo: String
    let source: Source

    enum Source {
        case manual
        case healthKit
    }
}

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

    // HealthKit data
    var healthKitItems: [BodyCompositionListItem] = []
    var isLoadingHealthKit = false

    // Form fields
    var newWeight: String = ""
    var newBodyFat: String = ""
    var newMuscleMass: String = ""
    var newMemo: String = ""
    var selectedDate: Date = Date() { didSet { validationError = nil } }
    var validationError: String?
    var isSaving = false

    private let bodyCompositionService: BodyCompositionQuerying

    init(bodyCompositionService: BodyCompositionQuerying? = nil) {
        self.bodyCompositionService = bodyCompositionService ?? BodyCompositionQueryService(manager: .shared)
    }

    func loadHealthKitData() async {
        isLoadingHealthKit = true
        do {
            async let weightTask = bodyCompositionService.fetchWeight(days: 90)
            async let bodyFatTask = bodyCompositionService.fetchBodyFat(days: 90)
            async let leanBodyMassTask = bodyCompositionService.fetchLeanBodyMass(days: 90)

            let (weights, bodyFats, leanBodyMasses) = try await (weightTask, bodyFatTask, leanBodyMassTask)

            // Merge by date (group samples from same day)
            var dateMap: [String: (weight: Double?, bodyFat: Double?, muscleMass: Double?, date: Date)] = [:]
            let calendar = Calendar.current

            for sample in weights {
                let key = dayKey(sample.date, calendar: calendar)
                var entry = dateMap[key] ?? (weight: nil, bodyFat: nil, muscleMass: nil, date: sample.date)
                entry.weight = sample.value
                if sample.date > entry.date { entry.date = sample.date }
                dateMap[key] = entry
            }

            for sample in bodyFats {
                let key = dayKey(sample.date, calendar: calendar)
                var entry = dateMap[key] ?? (weight: nil, bodyFat: nil, muscleMass: nil, date: sample.date)
                entry.bodyFat = sample.value
                if sample.date > entry.date { entry.date = sample.date }
                dateMap[key] = entry
            }

            for sample in leanBodyMasses {
                let key = dayKey(sample.date, calendar: calendar)
                var entry = dateMap[key] ?? (weight: nil, bodyFat: nil, muscleMass: nil, date: sample.date)
                entry.muscleMass = sample.value
                if sample.date > entry.date { entry.date = sample.date }
                dateMap[key] = entry
            }

            healthKitItems = dateMap.map { key, entry in
                BodyCompositionListItem(
                    id: "hk-\(key)",
                    date: entry.date,
                    weight: entry.weight,
                    bodyFatPercentage: entry.bodyFat,
                    muscleMass: entry.muscleMass,
                    memo: "",
                    source: .healthKit
                )
            }.sorted { $0.date > $1.date }
        } catch {
            AppLogger.ui.error("Body composition HK load failed: \(error.localizedDescription)")
        }
        isLoadingHealthKit = false
    }

    func allItems(manualRecords: [BodyCompositionRecord]) -> [BodyCompositionListItem] {
        let manualItems = manualRecords.map { record in
            BodyCompositionListItem(
                id: record.id.uuidString,
                date: record.date,
                weight: record.weight,
                bodyFatPercentage: record.bodyFatPercentage,
                muscleMass: record.muscleMass,
                memo: record.memo,
                source: .manual
            )
        }
        return (manualItems + healthKitItems).sorted { $0.date > $1.date }
    }

    func latestValues(manualRecords: [BodyCompositionRecord]) -> BodyCompositionListItem? {
        allItems(manualRecords: manualRecords).first
    }

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

    // MARK: - Private

    private func dayKey(_ date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}
