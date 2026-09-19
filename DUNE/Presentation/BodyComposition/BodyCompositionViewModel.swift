import Foundation
import Observation

struct BodyCompositionListItem: Identifiable, Sendable {
    let id: String
    let date: Date
    let weight: Double?
    let bodyFatPercentage: Double?
    let muscleMass: Double?
    let memo: String
    let source: Source

    enum Source: Sendable {
        case manual
        case healthKit
    }
}

struct BodyCompositionFormDraft: Sendable {
    let date: Date
    let weight: Double?
    let bodyFatPercentage: Double?
    let muscleMass: Double?
    let memo: String

    var writeInput: BodyCompositionWriteInput {
        BodyCompositionWriteInput(
            date: date,
            weight: weight,
            bodyFatPercentage: bodyFatPercentage,
            leanBodyMass: muscleMass
        )
    }

    func makeRecord() -> BodyCompositionRecord {
        BodyCompositionRecord(
            date: date,
            weight: weight,
            bodyFatPercentage: bodyFatPercentage,
            muscleMass: muscleMass,
            memo: memo
        )
    }

    func apply(to record: BodyCompositionRecord) {
        record.date = date
        record.weight = weight
        record.bodyFatPercentage = bodyFatPercentage
        record.muscleMass = muscleMass
        record.memo = memo
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

    private var healthKitRequestID = 0

    func loadHealthKitData() async {
        healthKitRequestID += 1
        let requestID = healthKitRequestID
        isLoadingHealthKit = true
        defer {
            if requestID == healthKitRequestID { isLoadingHealthKit = false }
        }
        do {
            let end = Date()
            async let weightTask = bodyCompositionService.fetchWeight(start: .distantPast, end: end)
            async let bodyFatTask = bodyCompositionService.fetchBodyFat(start: .distantPast, end: end)
            async let leanBodyMassTask = bodyCompositionService.fetchLeanBodyMass(start: .distantPast, end: end)
            let (weights, bodyFats, leanBodyMasses) = try await (weightTask, bodyFatTask, leanBodyMassTask)
            try Task.checkCancellation()
            guard requestID == healthKitRequestID else { return }
            let items = await Task.detached(priority: .userInitiated) {
                Self.mergeHistory(weights: weights, bodyFats: bodyFats, leanBodyMasses: leanBodyMasses)
            }.value
            guard !Task.isCancelled, requestID == healthKitRequestID else { return }
            healthKitItems = items
        } catch is CancellationError {
            // Keep the currently displayed history when leaving or refreshing the screen.
        } catch {
            AppLogger.ui.error("Body composition HK load failed: \(error.localizedDescription)")
        }
    }

    nonisolated static func mergeHistory(
        weights: [BodyCompositionSample],
        bodyFats: [BodyCompositionSample],
        leanBodyMasses: [BodyCompositionSample]
    ) -> [BodyCompositionListItem] {
        let historyWeights = weights.filter { !$0.isManagedByDuneSync }.sorted { $0.date > $1.date }
        let historyBodyFats = bodyFats.filter { !$0.isManagedByDuneSync }.sorted { $0.date > $1.date }
        let historyLeanBodyMasses = leanBodyMasses.filter { !$0.isManagedByDuneSync }.sorted { $0.date > $1.date }

        // Merge by date (group samples from same day)
        var dateMap: [String: (weight: Double?, bodyFat: Double?, muscleMass: Double?, date: Date)] = [:]
        let calendar = Calendar.current

        for sample in historyWeights {
            let key = dayKey(sample.date, calendar: calendar)
            var entry = dateMap[key] ?? (weight: nil, bodyFat: nil, muscleMass: nil, date: sample.date)
            if entry.weight == nil { entry.weight = sample.value }
            if sample.date > entry.date { entry.date = sample.date }
            dateMap[key] = entry
        }

        for sample in historyBodyFats {
            let key = dayKey(sample.date, calendar: calendar)
            var entry = dateMap[key] ?? (weight: nil, bodyFat: nil, muscleMass: nil, date: sample.date)
            if entry.bodyFat == nil { entry.bodyFat = sample.value }
            if sample.date > entry.date { entry.date = sample.date }
            dateMap[key] = entry
        }

        for sample in historyLeanBodyMasses {
            let key = dayKey(sample.date, calendar: calendar)
            var entry = dateMap[key] ?? (weight: nil, bodyFat: nil, muscleMass: nil, date: sample.date)
            if entry.muscleMass == nil { entry.muscleMass = sample.value }
            if sample.date > entry.date { entry.date = sample.date }
            dateMap[key] = entry
        }

        return dateMap.map { key, entry in
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

    func createValidatedDraft() -> BodyCompositionFormDraft? {
        guard !isSaving else { return nil }

        if selectedDate.isFuture {
            validationError = String(localized: "Future dates are not allowed")
            return nil
        }

        guard let validated = validateInputs() else { return nil }
        isSaving = true
        return BodyCompositionFormDraft(
            date: selectedDate,
            weight: validated.weight,
            bodyFatPercentage: validated.bodyFat,
            muscleMass: validated.muscleMass,
            memo: String(newMemo.prefix(maxMemoLength))
        )
    }

    func createValidatedRecord() -> BodyCompositionRecord? {
        createValidatedDraft()?.makeRecord()
    }

    func didFinishSaving() {
        isSaving = false
    }

    func apply(_ draft: BodyCompositionFormDraft, to record: BodyCompositionRecord) {
        draft.apply(to: record)
    }

    private func validateInputs() -> (weight: Double?, bodyFat: Double?, muscleMass: Double?)? {
        validationError = nil

        if newWeight.isEmpty && newBodyFat.isEmpty && newMuscleMass.isEmpty {
            validationError = String(localized: "Enter at least one body measurement")
            return nil
        }

        let weight: Double? = newWeight.isEmpty ? nil : Double(newWeight)
        if !newWeight.isEmpty {
            guard let w = weight, w > 0, w < maxWeight else {
                validationError = String(localized: "Weight must be between 0 and \(Int(maxWeight)) kg")
                return nil
            }
        }

        let bodyFat: Double? = newBodyFat.isEmpty ? nil : Double(newBodyFat)
        if !newBodyFat.isEmpty {
            guard let bf = bodyFat, bf >= 0, bf <= maxBodyFat else {
                validationError = String(localized: "Body fat must be between 0% and \(Int(maxBodyFat))%")
                return nil
            }
        }

        let muscleMass: Double? = newMuscleMass.isEmpty ? nil : Double(newMuscleMass)
        if !newMuscleMass.isEmpty {
            guard let mm = muscleMass, mm > 0, mm < maxMuscleMass else {
                validationError = String(localized: "Muscle mass must be between 0 and \(Int(maxMuscleMass)) kg")
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

    nonisolated private static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}
