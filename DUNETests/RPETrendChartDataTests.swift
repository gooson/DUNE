import Foundation
import Testing
@testable import DUNE

@Suite("RPE Trend Chart Data Aggregation")
struct RPETrendChartDataTests {

    // MARK: - Empty / No Data

    @Test("Empty records returns empty trend data")
    func emptyRecordsReturnsEmpty() {
        let result = TrainingVolumeViewModel.buildRPETrendData(from: [], historyDays: 28)
        #expect(result.isEmpty)
    }

    @Test("Records with all nil RPE returns empty")
    func allNilRPEReturnsEmpty() {
        let records = [
            makeRecord(daysAgo: 1, rpe: nil),
            makeRecord(daysAgo: 2, rpe: nil)
        ]
        let result = TrainingVolumeViewModel.buildRPETrendData(from: records, historyDays: 28)
        #expect(result.isEmpty)
    }

    // MARK: - Single Session

    @Test("Single session produces single data point")
    func singleSession() {
        let records = [makeRecord(daysAgo: 1, rpe: 7)]
        let result = TrainingVolumeViewModel.buildRPETrendData(from: records, historyDays: 28)
        #expect(result.count == 1)
        #expect(result[0].averageRPE == 7.0)
        #expect(result[0].sessionCount == 1)
    }

    // MARK: - Multiple Sessions Same Day

    @Test("Multiple sessions on same day averaged")
    func multipleSameDay() {
        let records = [
            makeRecord(daysAgo: 1, rpe: 6),
            makeRecord(daysAgo: 1, rpe: 8),
            makeRecord(daysAgo: 1, rpe: 10)
        ]
        let result = TrainingVolumeViewModel.buildRPETrendData(from: records, historyDays: 28)
        #expect(result.count == 1)
        #expect(result[0].averageRPE == 8.0) // (6+8+10)/3
        #expect(result[0].sessionCount == 3)
    }

    // MARK: - Nil RPE Excluded

    @Test("Nil RPE sessions excluded from aggregation")
    func nilRPEExcluded() {
        let records = [
            makeRecord(daysAgo: 1, rpe: 8),
            makeRecord(daysAgo: 1, rpe: nil),
            makeRecord(daysAgo: 2, rpe: nil)
        ]
        let result = TrainingVolumeViewModel.buildRPETrendData(from: records, historyDays: 28)
        #expect(result.count == 1) // Only day 1 has valid RPE
        #expect(result[0].averageRPE == 8.0)
    }

    // MARK: - Out of Range RPE Excluded

    @Test("RPE values outside 1-10 are excluded")
    func outOfRangeExcluded() {
        let records = [
            makeRecord(daysAgo: 1, rpe: 0),
            makeRecord(daysAgo: 1, rpe: 11),
            makeRecord(daysAgo: 2, rpe: 5)
        ]
        let result = TrainingVolumeViewModel.buildRPETrendData(from: records, historyDays: 28)
        #expect(result.count == 1) // Only day 2 has valid RPE
        #expect(result[0].averageRPE == 5.0)
    }

    // MARK: - History Window

    @Test("Records outside history window excluded")
    func historyWindowRespected() {
        let records = [
            makeRecord(daysAgo: 5, rpe: 8),
            makeRecord(daysAgo: 15, rpe: 6)
        ]
        let result = TrainingVolumeViewModel.buildRPETrendData(from: records, historyDays: 7)
        #expect(result.count == 1) // Only 5 days ago is within 7-day window
        #expect(result[0].averageRPE == 8.0)
    }

    // MARK: - Ordering

    @Test("Results are ordered chronologically")
    func chronologicalOrder() {
        let records = [
            makeRecord(daysAgo: 3, rpe: 6),
            makeRecord(daysAgo: 1, rpe: 8),
            makeRecord(daysAgo: 5, rpe: 7)
        ]
        let result = TrainingVolumeViewModel.buildRPETrendData(from: records, historyDays: 28)
        #expect(result.count == 3)
        // Should be sorted by date ascending
        #expect(result[0].date < result[1].date)
        #expect(result[1].date < result[2].date)
    }

    // MARK: - RPETrendDataPoint Identity

    @Test("RPETrendDataPoint id is date")
    func dataPointIdentity() {
        let date = Calendar.current.startOfDay(for: Date())
        let point = RPETrendDataPoint(date: date, averageRPE: 7.5, sessionCount: 2)
        #expect(point.id == date)
    }

    // MARK: - Helpers

    private func makeRecord(daysAgo: Int, rpe: Int?) -> ExerciseRecord {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        let record = ExerciseRecord(exerciseType: "Test", date: date)
        record.rpe = rpe
        return record
    }
}
