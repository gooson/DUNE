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
        daysAgo: Int,
        title: String = "PR"
    ) -> ActivityPersonalRecord {
        ActivityPersonalRecord(
            id: id,
            kind: kind,
            title: title,
            value: value,
            date: date(daysAgo),
            isRecent: daysAgo <= 7,
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
        #expect(vm.personalRecords[0].id == "c")
        #expect(vm.personalRecords[1].id == "b")
        #expect(vm.personalRecords[2].id == "a")
        #expect(vm.personalRecords[3].id == "d")
    }

    @Test("availableKinds returns unique sorted kinds")
    func availableKinds() {
        let vm = PersonalRecordsDetailViewModel()
        vm.load(records: [
            makeRecord(id: "1", kind: .estimated1RM, value: 120, daysAgo: 1),
            makeRecord(id: "2", kind: .strengthWeight, value: 100, daysAgo: 1),
            makeRecord(id: "3", kind: .estimated1RM, value: 110, daysAgo: 5),
        ])
        #expect(vm.availableKinds == [.estimated1RM, .strengthWeight])
    }

    @Test("resolvedKind falls back to first available kind")
    func resolvedKindFallback() {
        let vm = PersonalRecordsDetailViewModel()
        vm.load(records: [
            makeRecord(id: "1", kind: .sessionVolume, value: 1000, daysAgo: 1),
        ])
        #expect(vm.resolvedKind == .sessionVolume)
    }

    @Test("filteredRecords returns only records matching kind and period")
    func filteredRecordsByKindAndPeriod() {
        let vm = PersonalRecordsDetailViewModel()
        vm.selectedPeriod = .month
        vm.selectedKind = .estimated1RM
        vm.load(records: [
            makeRecord(id: "1", kind: .estimated1RM, value: 120, daysAgo: 5),
            makeRecord(id: "2", kind: .estimated1RM, value: 110, daysAgo: 60),  // Outside month
            makeRecord(id: "3", kind: .strengthWeight, value: 100, daysAgo: 1),  // Wrong kind
        ])
        #expect(vm.filteredRecords.count == 1)
        #expect(vm.filteredRecords[0].id == "1")
    }

    @Test("currentBest returns highest value for non-lower-better kind")
    func currentBestHighest() {
        let vm = PersonalRecordsDetailViewModel()
        vm.selectedKind = .estimated1RM
        vm.load(records: [
            makeRecord(id: "1", kind: .estimated1RM, value: 120, daysAgo: 5),
            makeRecord(id: "2", kind: .estimated1RM, value: 150, daysAgo: 30),
            makeRecord(id: "3", kind: .estimated1RM, value: 110, daysAgo: 1),
        ])
        #expect(vm.currentBest?.value == 150)
    }

    @Test("currentBest returns lowest value for fastestPace")
    func currentBestLowest() {
        let vm = PersonalRecordsDetailViewModel()
        vm.selectedKind = .fastestPace
        vm.load(records: [
            makeRecord(id: "1", kind: .fastestPace, value: 300, daysAgo: 5),
            makeRecord(id: "2", kind: .fastestPace, value: 280, daysAgo: 10),
            makeRecord(id: "3", kind: .fastestPace, value: 320, daysAgo: 1),
        ])
        #expect(vm.currentBest?.value == 280)
    }

    @Test("chartData returns records sorted oldest first")
    func chartDataAscending() {
        let vm = PersonalRecordsDetailViewModel()
        vm.selectedPeriod = .year
        vm.selectedKind = .strengthWeight
        vm.load(records: [
            makeRecord(id: "1", kind: .strengthWeight, value: 100, daysAgo: 1),
            makeRecord(id: "2", kind: .strengthWeight, value: 80, daysAgo: 30),
            makeRecord(id: "3", kind: .strengthWeight, value: 90, daysAgo: 15),
        ])
        let dates = vm.chartData.map(\.date)
        #expect(dates == dates.sorted())
    }

    @Test("allTimeRecords ignores period filter")
    func allTimeRecordsIgnoresPeriod() {
        let vm = PersonalRecordsDetailViewModel()
        vm.selectedPeriod = .month
        vm.selectedKind = .estimated1RM
        vm.load(records: [
            makeRecord(id: "1", kind: .estimated1RM, value: 120, daysAgo: 5),
            makeRecord(id: "2", kind: .estimated1RM, value: 110, daysAgo: 60),
        ])
        #expect(vm.allTimeRecords.count == 2)
    }

    @Test("new PR kinds appear in availableKinds with correct sort order")
    func newKindsSortOrder() {
        let vm = PersonalRecordsDetailViewModel()
        vm.load(records: [
            makeRecord(id: "1", kind: .estimated1RM, value: 120, daysAgo: 1),
            makeRecord(id: "2", kind: .repMax, value: 100, daysAgo: 1),
            makeRecord(id: "3", kind: .sessionVolume, value: 5000, daysAgo: 1),
            makeRecord(id: "4", kind: .strengthWeight, value: 90, daysAgo: 1),
        ])
        let kinds = vm.availableKinds
        #expect(kinds == [.estimated1RM, .repMax, .sessionVolume, .strengthWeight])
    }
}
