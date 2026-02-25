import Foundation
import Observation

@Observable
@MainActor
final class InjuryViewModel {
    private let maxMemoLength = 500
    private let statisticsService = InjuryStatisticsService()
    private let conflictUseCase = CheckInjuryConflictUseCase()

    // MARK: - Sheet State

    var isShowingAddSheet = false
    var isShowingEditSheet = false
    var editingRecord: InjuryRecord?

    // MARK: - Form Fields

    var selectedBodyPart: BodyPart = .knee
    var selectedSide: BodySide? = nil
    var selectedSeverity: InjurySeverity = .moderate
    var startDate: Date = Date() { didSet { validationError = nil } }
    var endDate: Date?
    var memo: String = ""
    var validationError: String?
    var isSaving = false

    // MARK: - Statistics

    var statistics: InjuryStatistics?
    var volumeComparisons: [InjuryVolumeComparison] = []

    // MARK: - CRUD

    func createValidatedRecord() -> InjuryRecord? {
        guard !isSaving else { return nil }

        guard let validated = validateInputs() else { return nil }
        isSaving = true

        return InjuryRecord(
            bodyPart: validated.bodyPart,
            bodySide: validated.side,
            severity: validated.severity,
            startDate: validated.startDate,
            endDate: validated.endDate,
            memo: String(memo.prefix(maxMemoLength))
        )
    }

    /// Call from View after `modelContext.insert(record)` completes.
    func didFinishSaving() {
        isSaving = false
    }

    func applyUpdate(to record: InjuryRecord) -> Bool {
        guard !isSaving else { return false }
        guard let validated = validateInputs() else { return false }
        isSaving = true

        record.bodyPartRaw = validated.bodyPart.rawValue
        record.bodySideRaw = validated.side?.rawValue
        record.severityRaw = validated.severity.rawValue
        record.startDate = validated.startDate
        record.endDate = validated.endDate
        record.memo = String(memo.prefix(maxMemoLength))
        isSaving = false
        return true
    }

    func markAsRecovered(_ record: InjuryRecord) {
        guard !isSaving else { return }
        record.endDate = Date()
    }

    // MARK: - Form Helpers

    func startEditing(_ record: InjuryRecord) {
        editingRecord = record
        selectedBodyPart = record.bodyPart
        selectedSide = record.bodySide
        selectedSeverity = record.severity
        startDate = record.startDate
        endDate = record.endDate
        memo = record.memo
        validationError = nil
        isShowingEditSheet = true
    }

    func resetForm() {
        selectedBodyPart = .knee
        selectedSide = nil
        selectedSeverity = .moderate
        startDate = Date()
        endDate = nil
        memo = ""
        validationError = nil
        editingRecord = nil
    }

    // MARK: - Statistics

    func loadStatistics(from records: [InjuryRecord], exerciseDates: [Date] = []) {
        let infos = records.map { $0.toInjuryInfo() }
        statistics = statisticsService.computeStatistics(from: infos)
        if !infos.isEmpty, !exerciseDates.isEmpty {
            volumeComparisons = statisticsService.computeVolumeComparisons(
                injuries: infos,
                exerciseDates: exerciseDates
            )
        } else {
            volumeComparisons = []
        }
    }

    // MARK: - Conflict Checking

    func checkConflicts(
        exerciseMuscles: [MuscleGroup],
        activeInjuries: [InjuryRecord]
    ) -> CheckInjuryConflictUseCase.Output {
        let infos = activeInjuries.filter(\.isActive).map { $0.toInjuryInfo() }
        return conflictUseCase.execute(input: .init(
            exerciseMuscles: exerciseMuscles,
            activeInjuries: infos
        ))
    }

    // MARK: - Active Injury Helpers

    func activeInjuryInfos(from records: [InjuryRecord]) -> [InjuryInfo] {
        records.filter(\.isActive).map { $0.toInjuryInfo() }
    }

    func injuredMuscleGroups(from records: [InjuryRecord]) -> Set<MuscleGroup> {
        let infos = activeInjuryInfos(from: records)
        return Set(infos.flatMap(\.affectedMuscleGroups))
    }

    // MARK: - Validation

    private struct ValidatedInput {
        let bodyPart: BodyPart
        let side: BodySide?
        let severity: InjurySeverity
        let startDate: Date
        let endDate: Date?
    }

    /// Earliest allowed start date (~10 years ago).
    private static let earliestStartDate: Date = {
        Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date()
    }()

    private func validateInputs() -> ValidatedInput? {
        validationError = nil

        if startDate.isFuture {
            validationError = "Start date cannot be in the future"
            return nil
        }

        if startDate < Self.earliestStartDate {
            validationError = "Start date is too far in the past"
            return nil
        }

        if let end = endDate {
            if end < startDate {
                validationError = "End date must be after start date"
                return nil
            }
            if end.isFuture {
                validationError = "End date cannot be in the future"
                return nil
            }
        }

        // Side is required for lateral body parts, cleared for non-lateral
        let side: BodySide?
        if selectedBodyPart.isLateral {
            side = selectedSide ?? .both
        } else {
            side = nil
        }

        return ValidatedInput(
            bodyPart: selectedBodyPart,
            side: side,
            severity: selectedSeverity,
            startDate: startDate,
            endDate: endDate
        )
    }
}
