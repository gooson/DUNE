import Foundation
import Testing
@testable import DUNE

@Suite("PersonalRecordsDetailViewModel")
@MainActor
struct PersonalRecordsDetailViewModelTests {
    private let calendar = Calendar.current

    private func date(_ daysAgo: Int) -> Date {
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
    }

    private func makeRecord(
        id: String,
        kind: ActivityPersonalRecord.Kind,
        value: Double,
        daysAgo: Int
    ) -> ActivityPersonalRecord {
        ActivityPersonalRecord(
            id: id,
            kind: kind,
            title: "PR",
            value: value,
            date: date(daysAgo),
            isRecent: true,
            source: .manual
        )
    }

    @Test("load sorts by date desc, kind sortOrder asc, value desc")
    func sortingOrder() {
        let vm = PersonalRecordsDetailViewModel()
        let sameDay = date(0)

        let records: [ActivityPersonalRecord] = [
            ActivityPersonalRecord(id: "a", kind: .highestCalories, title: "A", value: 400, date: sameDay, isRecent: true, source: .manual),
            ActivityPersonalRecord(id: "b", kind: .strengthWeight, title: "B", value: 100, date: sameDay, isRecent: true, source: .manual),
            ActivityPersonalRecord(id: "c", kind: .strengthWeight, title: "C", value: 120, date: sameDay, isRecent: true, source: .manual),
            makeRecord(id: "d", kind: .longestDuration, value: 60, daysAgo: 3),
        ]

        vm.load(records: records)

        #expect(vm.personalRecords.count == 4)
        // Same day records first, and within same kind/value sorted by value desc
        #expect(vm.personalRecords[0].id == "c")
        #expect(vm.personalRecords[1].id == "b")
        #expect(vm.personalRecords[2].id == "a")
        #expect(vm.personalRecords[3].id == "d")
    }
}
