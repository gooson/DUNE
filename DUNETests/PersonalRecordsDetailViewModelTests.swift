import Foundation
import Testing
@testable import DUNE

private struct PaceHistoryWorkoutService: WorkoutQuerying {
    let workouts: [WorkoutSummary]

    func fetchWorkouts(days: Int) async throws -> [WorkoutSummary] { workouts }
    func fetchWorkouts(start: Date, end: Date) async throws -> [WorkoutSummary] { workouts }
}

private actor PausedPaceHistoryWorkoutService: WorkoutQuerying {
    private var fetchContinuation: CheckedContinuation<[WorkoutSummary], Never>?
    private var startedContinuation: CheckedContinuation<Void, Never>?

    func fetchWorkouts(days: Int) async throws -> [WorkoutSummary] { [] }

    func fetchWorkouts(start: Date, end: Date) async throws -> [WorkoutSummary] {
        await withCheckedContinuation { continuation in
            fetchContinuation = continuation
            startedContinuation?.resume()
            startedContinuation = nil
        }
    }

    func waitUntilStarted() async {
        if fetchContinuation != nil { return }
        await withCheckedContinuation { startedContinuation = $0 }
    }

    func finish(with workouts: [WorkoutSummary]) {
        fetchContinuation?.resume(returning: workouts)
        fetchContinuation = nil
    }
}

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

    private func makeWorkout(
        id: String,
        pace: Double?,
        daysAgo: Int,
        activityType: WorkoutActivityType = .running
    ) -> WorkoutSummary {
        WorkoutSummary(
            id: id,
            type: activityType.rawValue,
            activityType: activityType,
            duration: 1_800,
            calories: 250,
            distance: 5_000,
            date: date(daysAgo),
            averagePace: pace
        )
    }

    @Test("Day includes midnight through now and preserves distinct same-day points")
    func dayBoundaries() {
        let reference = Date(timeIntervalSince1970: 1_730_650_000)
        let midnight = calendar.startOfDay(for: reference)
        let vm = PersonalRecordsDetailViewModel(now: { reference })
        vm.selectedPeriod = .day
        let dates = [midnight.addingTimeInterval(-1), midnight, midnight.addingTimeInterval(1), reference, reference.addingTimeInterval(1)]
        vm.load(records: dates.enumerated().map { index, date in
            ActivityPersonalRecord(id: "\(index)", kind: .strengthWeight, title: "PR", value: Double(index), date: date, isRecent: false, source: .manual)
        })

        #expect(vm.chartDateRange.start == midnight)
        #expect(vm.chartDateRange.end == reference)
        #expect(vm.chartData.map(\.id) == ["1", "2", "3"])
        #expect(Set(vm.filteredRecords.map(\.id)) == Set(["1", "2", "3"]))
    }

    @Test("Week includes seven local dates through now and excludes outside points")
    func weekBoundaries() throws {
        let reference = Date(timeIntervalSince1970: 1_730_650_000)
        let midnight = calendar.startOfDay(for: reference)
        let start = try #require(calendar.date(byAdding: .day, value: -6, to: midnight))
        let vm = PersonalRecordsDetailViewModel(now: { reference })
        vm.selectedPeriod = .week
        let dates = [start.addingTimeInterval(-1), start, midnight, reference, reference.addingTimeInterval(1)]
        vm.load(records: dates.enumerated().map { index, date in
            ActivityPersonalRecord(id: "\(index)", kind: .strengthWeight, title: "PR", value: Double(index), date: date, isRecent: false, source: .manual)
        })

        #expect(vm.chartDateRange.start == start)
        #expect(vm.chartDateRange.end == reference)
        #expect(vm.chartData.map(\.id) == ["1", "2", "3"])
    }

    @Test("An empty period retains the older all-time best")
    func emptyPeriodRetainsBest() throws {
        let reference = Date(timeIntervalSince1970: 1_730_650_000)
        let oldDate = try #require(calendar.date(byAdding: .day, value: -10, to: reference))
        let vm = PersonalRecordsDetailViewModel(now: { reference })
        vm.selectedPeriod = .day
        vm.load(records: [ActivityPersonalRecord(id: "best", kind: .strengthWeight, title: "PR", value: 150, date: oldDate, isRecent: false, source: .manual)])

        #expect(vm.chartData.isEmpty)
        #expect(vm.filteredRecords.isEmpty)
        #expect(vm.currentBest?.id == "best")
    }

    @Test("Pace period uses actual workouts while the lowest all-time record remains best")
    func pacePeriodUsesWorkouts() throws {
        let reference = Date(timeIntervalSince1970: 1_730_650_000)
        let midnight = calendar.startOfDay(for: reference)
        let oldDate = try #require(calendar.date(byAdding: .day, value: -10, to: reference))
        let vm = PersonalRecordsDetailViewModel(now: { reference })
        vm.selectedPeriod = .day
        vm.load(records: [ActivityPersonalRecord(id: "best", kind: .fastestPace, title: "PR", value: 280, date: oldDate, isRecent: false, source: .manual)])
        let workouts = [("before", midnight.addingTimeInterval(-1), 300.0), ("today", midnight, 320.0), ("future", reference.addingTimeInterval(1), 310.0)].map { id, date, pace in
            WorkoutSummary(id: id, type: WorkoutActivityType.running.rawValue, activityType: .running, duration: 1_800, calories: 250, distance: 5_000, date: date, averagePace: pace)
        }
        vm.addPaceWorkouts(workouts)

        #expect(vm.chartData.map(\.id) == ["pace-workout-today"])
        #expect(vm.currentBest?.value == 280)
    }

    @Test("The detail exposes five periods and defaults to six months")
    func availablePeriods() {
        #expect(PersonalRecordsDetailViewModel.availablePeriods == [.day, .week, .month, .sixMonths, .year])
        #expect(PersonalRecordsDetailViewModel().selectedPeriod == .sixMonths)
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

    @Test("Pace chart shows workouts in the selected month when the all-time best is older")
    func paceHistoryWithOldBest() {
        let vm = PersonalRecordsDetailViewModel()
        vm.selectedKind = .fastestPace
        vm.selectedPeriod = .month
        vm.load(records: [makeRecord(id: "best", kind: .fastestPace, value: 384, daysAgo: 200)])
        vm.addPaceWorkouts([
            makeWorkout(id: "newer", pace: 410, daysAgo: 2),
            makeWorkout(id: "older", pace: 425, daysAgo: 10),
        ])

        #expect(vm.currentBest?.value == 384)
        #expect(vm.filteredRecords.isEmpty)
        #expect(vm.chartData.map(\.value) == [425, 410])
    }

    @Test("Pace history excludes invalid and unrelated workouts and deduplicates refreshes")
    func paceHistoryValidation() {
        let vm = PersonalRecordsDetailViewModel()
        vm.selectedKind = .fastestPace
        vm.selectedPeriod = .month
        vm.load(records: [makeRecord(id: "best", kind: .fastestPace, value: 384, daysAgo: 100)])
        let valid = makeWorkout(id: "valid", pace: 410, daysAgo: 1)
        vm.addPaceWorkouts([
            valid,
            makeWorkout(id: "zero", pace: 0, daysAgo: 1),
            makeWorkout(id: "infinite", pace: .infinity, daysAgo: 1),
            makeWorkout(id: "other", pace: 410, daysAgo: 1, activityType: .traditionalStrengthTraining),
        ])
        vm.addPaceWorkouts([valid])

        #expect(vm.chartData.map(\.id) == ["pace-workout-valid"])
    }

    @Test("Loading a year of workout history populates a past pace point")
    func loadsPaceHistory() async {
        let oldWorkout = makeWorkout(id: "past", pace: 420, daysAgo: 100)
        let vm = PersonalRecordsDetailViewModel(
            workoutService: PaceHistoryWorkoutService(workouts: [oldWorkout])
        )
        vm.selectedKind = .fastestPace
        vm.selectedPeriod = .year
        vm.load(records: [makeRecord(id: "best", kind: .fastestPace, value: 384, daysAgo: 200)])

        await vm.loadPaceHistoryIfNeeded()

        #expect(vm.hasLoadedPaceHistory)
        #expect(vm.chartData.map(\.id) == ["best", "pace-workout-past"])
    }

    @Test("Replacing the recent workout snapshot removes stale pace points")
    func paceHistoryReplacesRecentSnapshot() async {
        let old = makeWorkout(id: "old", pace: 420, daysAgo: 2)
        let replacement = makeWorkout(id: "replacement", pace: 410, daysAgo: 1)
        let vm = PersonalRecordsDetailViewModel(
            workoutService: PaceHistoryWorkoutService(workouts: [old])
        )
        vm.selectedKind = .fastestPace
        vm.selectedPeriod = .month
        vm.load(records: [makeRecord(id: "best", kind: .fastestPace, value: 384, daysAgo: 100)])
        vm.addPaceWorkouts([old])
        await vm.loadPaceHistoryIfNeeded()
        #expect(vm.chartData.map(\.id) == ["pace-workout-old"])

        vm.addPaceWorkouts([replacement])
        #expect(!vm.hasLoadedPaceHistory)
        #expect(vm.chartData.map(\.id) == ["pace-workout-replacement"])
    }

    @Test("Cancelling a chip selection does not cancel the shared pace fetch")
    func paceHistorySurvivesSelectionCancellation() async {
        let workout = makeWorkout(id: "new", pace: 410, daysAgo: 1)
        let service = PausedPaceHistoryWorkoutService()
        let vm = PersonalRecordsDetailViewModel(workoutService: service)
        vm.selectedKind = .fastestPace
        vm.selectedPeriod = .month
        vm.load(records: [makeRecord(id: "best", kind: .fastestPace, value: 384, daysAgo: 100)])

        let firstSelection = Task { await vm.loadPaceHistoryIfNeeded() }
        await service.waitUntilStarted()
        firstSelection.cancel()
        let secondSelection = Task { await vm.loadPaceHistoryIfNeeded() }
        await Task.yield()
        await service.finish(with: [workout])
        await firstSelection.value
        await secondSelection.value

        #expect(vm.hasLoadedPaceHistory)
        #expect(vm.chartData.map(\.id) == ["pace-workout-new"])
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
