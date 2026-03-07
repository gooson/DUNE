import Foundation
import Testing
@testable import DUNE

@Suite("StrengthPersonalRecord")
struct StrengthPersonalRecordTests {

    // MARK: - Weight Clamping

    @Test("Negative weight is clamped to 0")
    func negativeWeight() {
        let record = StrengthPersonalRecord(exerciseName: "Bench Press", maxWeight: -10, date: Date())
        #expect(record.maxWeight == 0)
    }

    @Test("Weight within range is unchanged")
    func normalWeight() {
        let record = StrengthPersonalRecord(exerciseName: "Bench Press", maxWeight: 100, date: Date())
        #expect(record.maxWeight == 100)
    }

    @Test("Weight above 500 is clamped to 500")
    func excessiveWeight() {
        let record = StrengthPersonalRecord(exerciseName: "Bench Press", maxWeight: 600, date: Date())
        #expect(record.maxWeight == 500)
    }

    @Test("Boundary values: 0 and 500 are preserved", arguments: [0.0, 500.0])
    func boundaryWeights(weight: Double) {
        let record = StrengthPersonalRecord(exerciseName: "Bench Press", maxWeight: weight, date: Date())
        #expect(record.maxWeight == weight)
    }

    // MARK: - isRecent

    @Test("Today's date is recent")
    func todayIsRecent() {
        let now = Date()
        let record = StrengthPersonalRecord(exerciseName: "Squat", maxWeight: 100, date: now, referenceDateForRecent: now)
        #expect(record.isRecent == true)
    }

    @Test("7 days ago is recent (boundary)")
    func sevenDaysAgoIsRecent() throws {
        let now = Date()
        let sevenDaysAgo = try #require(Calendar.current.date(byAdding: .day, value: -7, to: now))
        let record = StrengthPersonalRecord(exerciseName: "Squat", maxWeight: 100, date: sevenDaysAgo, referenceDateForRecent: now)
        #expect(record.isRecent == true)
    }

    @Test("8 days ago is not recent")
    func eightDaysAgoIsNotRecent() throws {
        let now = Date()
        let eightDaysAgo = try #require(Calendar.current.date(byAdding: .day, value: -8, to: now))
        let record = StrengthPersonalRecord(exerciseName: "Squat", maxWeight: 100, date: eightDaysAgo, referenceDateForRecent: now)
        #expect(record.isRecent == false)
    }
}
