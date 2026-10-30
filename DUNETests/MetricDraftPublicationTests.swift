import Foundation
import Testing
@testable import DUNE

private enum DraftQueryError: Error { case unavailable }

private actor DraftHRVSource: HRVQuerying {
    private var rows: [(date: Date, average: Double)]
    private var fails = false
    init(date: Date, value: Double) { rows = [(date, value)] }
    func replace(date: Date, value: Double) { rows = [(date, value)] }
    func setFailure(_ value: Bool) { fails = value }
    func fetchHRVSamples(days: Int) async throws -> [HRVSample] { [] }
    func fetchRestingHeartRate(for date: Date) async throws -> Double? { nil }
    func fetchLatestRestingHeartRate(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchHRVCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, average: Double)] {
        if fails { throw DraftQueryError.unavailable }
        return rows.filter { $0.date >= start && $0.date < end }
    }
    func fetchRHRCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, min: Double, max: Double, average: Double)] { [] }
}

/// Holds exactly one metadata response. A bounded fallback releases every waiter
/// if a regression prevents the expected entry, rather than hanging the suite.
private actor DraftMetadataGate: MetricHistoryQuerying {
    private var armed = false
    private var entered = false
    private var expired = false
    private var response: CheckedContinuation<Void, Never>?
    private var entryWaiters: [CheckedContinuation<Bool, Never>] = []
    private var deadline: Task<Void, Never>?

    func arm() {
        armed = true
        entered = false
        expired = false
        deadline = Task {
            // Cancellation means the test released the response normally.
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            expire()
        }
    }
    func waitUntilEntered() async -> Bool {
        if entered { return true }
        if expired { return false }
        return await withCheckedContinuation { entryWaiters.append($0) }
    }
    func release() {
        armed = false
        deadline?.cancel()
        deadline = nil
        response?.resume()
        response = nil
    }
    private func expire() {
        expired = true
        armed = false
        entryWaiters.forEach { $0.resume(returning: false) }
        entryWaiters = []
        response?.resume()
        response = nil
    }
    func limitedReadStartDate(for category: HealthMetric.Category) async -> Date? {
        guard armed else { return nil }
        armed = false
        entered = true
        entryWaiters.forEach { $0.resume(returning: true) }
        entryWaiters = []
        await withCheckedContinuation { response = $0 }
        return nil
    }
    func earliestDate(for category: HealthMetric.Category) async throws -> Date? { nil }
    func latestDate(for category: HealthMetric.Category, before end: Date) async throws -> Date? { nil }
}

private actor DraftWorkoutSource: WorkoutQuerying {
    private var rows: [WorkoutSummary]
    init(_ rows: [WorkoutSummary]) { self.rows = rows }
    func replace(_ rows: [WorkoutSummary]) { self.rows = rows }
    func fetchWorkouts(days: Int) async throws -> [WorkoutSummary] { rows }
    func fetchWorkouts(start: Date, end: Date) async throws -> [WorkoutSummary] {
        rows.filter { $0.date >= start && $0.date < end }
    }
}

private struct DraftBodySource: BodyCompositionQuerying {
    let sample: BodyCompositionSample
    func fetchWeight(days: Int) async throws -> [BodyCompositionSample] { [sample] }
    func fetchBodyFat(days: Int) async throws -> [BodyCompositionSample] { [] }
    func fetchLeanBodyMass(days: Int) async throws -> [BodyCompositionSample] { [sample] }
    func fetchWeight(start: Date, end: Date) async throws -> [BodyCompositionSample] {
        sample.date >= start && sample.date < end ? [sample] : []
    }
    func fetchLeanBodyMass(start: Date, end: Date) async throws -> [BodyCompositionSample] {
        try await fetchWeight(start: start, end: end)
    }
    func fetchLatestWeight(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchBMI(for date: Date) async throws -> Double? { nil }
    func fetchLatestBMI(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchBMI(start: Date, end: Date) async throws -> [BodyCompositionSample] { [] }
    func fetchBodyFat(start: Date, end: Date) async throws -> [BodyCompositionSample] { [] }
    func fetchLatestBodyFat(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchLatestLeanBodyMass(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
}

private struct DraftStepsSource: StepsQuerying {
    let rows: [(date: Date, sum: Double)]
    func fetchSteps(for date: Date) async throws -> Double? { nil }
    func fetchLatestSteps(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchStepsCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, sum: Double)] {
        rows.filter { $0.date >= start && $0.date < end }
    }
}

@Suite("T06 draft publication and quantity contracts")
@MainActor
struct MetricDraftPublicationTests {
    private var date: Date { Calendar.current.startOfDay(for: Date()) }

    @Test("A staged same-count chart replacement hides old summary until metadata accepts it")
    func stagedReplacement() async {
        let date = self.date
        let source = DraftHRVSource(date: date, value: 20)
        let history = DraftMetadataGate()
        let vm = MetricDetailViewModel(hrvService: source, historyService: history)
        vm.configure(category: .hrv, currentValue: 20, lastUpdated: date, metricUnit: "ms")
        await vm.loadData()
        #expect(vm.visibleSummary?.statistics.average == 20)
        await source.replace(date: date, value: 40)
        await history.arm()
        let request = Task { await vm.loadData(historyNavigation: true) }
        let entered = await history.waitUntilEntered()
        #expect(entered)
        #expect(vm.chartData.first?.value == 40)
        #expect(vm.visibleSummary == nil)
        await history.release()
        await request.value
        #expect(vm.visibleSummary?.statistics.average == 40)
    }

    @Test("Failure before staging preserves the matching accepted chart and summary", arguments: [false, true])
    func failureBeforeStaging(historyNavigation: Bool) async {
        let date = self.date
        let source = DraftHRVSource(date: date, value: 20)
        let vm = MetricDetailViewModel(hrvService: source, historyService: DraftMetadataGate())
        vm.configure(category: .hrv, currentValue: 20, lastUpdated: date)
        await vm.loadData()
        await source.setFailure(true)
        await vm.loadData(historyNavigation: historyNavigation)
        #expect(vm.errorMessage != nil)
        #expect(vm.chartData.first?.value == 20)
        #expect(vm.visibleSummary?.statistics.average == 20)
    }

    @Test("Cancellation after staging cannot restore old summary, even if the next query fails")
    func cancellationAfterStaging() async {
        let date = self.date
        let source = DraftHRVSource(date: date, value: 20)
        let history = DraftMetadataGate()
        let vm = MetricDetailViewModel(hrvService: source, historyService: history)
        vm.configure(category: .hrv, currentValue: 20, lastUpdated: date)
        await vm.loadData()
        await source.replace(date: date, value: 40)
        await history.arm()
        let request = Task { await vm.loadData(historyNavigation: true) }
        let entered = await history.waitUntilEntered()
        #expect(entered)
        request.cancel()
        await history.release()
        await request.value
        #expect(vm.chartData.first?.value == 40)
        #expect(vm.visibleSummary == nil)
        await source.setFailure(true)
        await vm.loadData(historyNavigation: true)
        #expect(vm.visibleSummary == nil)
        await source.setFailure(false)
        await vm.loadData(historyNavigation: true)
        #expect(vm.visibleSummary?.statistics.average == 40)
    }

    @Test("Late metadata from a superseded request cannot replace a newer accepted summary")
    func supersededMetadata() async {
        let date = self.date
        let source = DraftHRVSource(date: date, value: 20)
        let history = DraftMetadataGate()
        let vm = MetricDetailViewModel(hrvService: source, historyService: history)
        vm.configure(category: .hrv, currentValue: 20, lastUpdated: date)
        await vm.loadData()
        await source.replace(date: date, value: 40)
        await history.arm()
        let stale = Task { await vm.loadData(historyNavigation: true) }
        let entered = await history.waitUntilEntered()
        #expect(entered)
        await source.replace(date: date, value: 60)
        await vm.loadData(historyNavigation: true)
        #expect(vm.visibleSummary?.statistics.average == 60)
        await history.release()
        await stale.value
        #expect(vm.chartData.first?.value == 60)
        #expect(vm.visibleSummary?.statistics.average == 60)
    }

    @Test("Exercise history resolves km/min without relabeling the actual running or swimming headline",
          arguments: ["Running", "Swimming"])
    func exerciseUnits(type: String) async {
        let date = self.date
        let meters = type == "Swimming" ? 1_000.0 : 10_200.0
        let metric = HealthMetric(id: type, name: type, value: type == "Swimming" ? meters : meters / 1_000,
                                  unit: type == "Swimming" ? "m" : "km", change: nil, date: date,
                                  category: .exercise, workoutTypeKey: type)
        let source = DraftWorkoutSource([
            WorkoutSummary(id: "distance", type: type, duration: 600, calories: nil, distance: meters, date: date),
            WorkoutSummary(id: "missing", type: type, duration: 300, calories: nil, distance: nil, date: date)
        ])
        let vm = MetricDetailViewModel(workoutService: source, historyService: DraftMetadataGate())
        vm.configure(category: .exercise, currentValue: metric.value, lastUpdated: date,
                     workoutTypeName: type, metricUnit: metric.unit)
        await vm.loadData()
        #expect(vm.metricUnit == "km")
        #expect(vm.visibleSummary?.unit == "km")
        #expect(vm.visibleSummary?.total == meters / 1_000)
        #expect(MetricDetailHeadline.resolve(metric, stepsValue: vm.currentValue, stepsUpdated: vm.lastUpdated) == metric)
        await source.replace([
            WorkoutSummary(id: "duration", type: type, duration: 600, calories: nil, distance: nil, date: date)
        ])
        await vm.loadData(historyNavigation: true)
        #expect(vm.metricUnit == "min")
        #expect(vm.visibleSummary?.unit == "min")
        #expect(vm.visibleSummary?.total == 10)
        #expect(MetricDetailHeadline.resolve(metric, stepsValue: vm.currentValue, stepsUpdated: vm.lastUpdated) == metric)
    }

    @Test("Canonical mass history remains kg when the actual headline is expressed in lb",
          arguments: [HealthMetric.Category.weight, .leanBodyMass])
    func bodyCanonicalUnit(category: HealthMetric.Category) async {
        let date = self.date
        let metric = HealthMetric(id: "body", name: "Body", value: WeightUnit.lb.fromKg(70), unit: "lb",
                                  change: nil, date: date, category: category)
        let vm = MetricDetailViewModel(bodyService: DraftBodySource(sample: .init(value: 70, date: date)),
                                       historyService: DraftMetadataGate())
        vm.configure(category: category, currentValue: metric.value, lastUpdated: date, metricUnit: "lb")
        await vm.loadData()
        #expect(vm.metricUnit == "kg")
        #expect(vm.visibleSummary?.unit == "kg")
        #expect(vm.visibleSummary?.statistics.average == 70)
        #expect(MetricDetailHeadline.resolve(metric, stepsValue: vm.currentValue, stepsUpdated: vm.lastUpdated) == metric)
    }

    @Test("Visible Steps total sums recorded rows while average remains a per-row average")
    func stepsTotal() async {
        let date = self.date
        let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        let source = DraftStepsSource(rows: [(previousDay, 100), (date, 300)])
        let vm = MetricDetailViewModel(stepsService: source, historyService: DraftMetadataGate())
        vm.configure(category: .steps, currentValue: 300, lastUpdated: date, metricUnit: "steps")
        await vm.loadData()
        #expect(vm.visibleSummary?.total == 400)
        #expect(vm.visibleSummary?.statistics.average == 200)
        #expect(vm.visibleSummary?.basis == .dailyTotals)
        #expect(vm.visibleSummary?.unit == "steps")
    }

    @Test("Only configured Steps substitute the existing ViewModel headline value/date",
          arguments: HealthMetric.Category.allCases)
    func headlineMapping(category: HealthMetric.Category) {
        let date = self.date
        let metric = HealthMetric(id: "metric", name: "Metric", value: 10, unit: "unit", change: 2,
                                  date: date, category: category, isHistorical: true,
                                  iconOverride: "figure.run", workoutTypeKey: "Running")
        let updated = date.addingTimeInterval(60)
        let result = MetricDetailHeadline.resolve(metric, stepsValue: 20, stepsUpdated: updated)
        if category == .steps {
            #expect(result.value == 20)
            #expect(result.date == updated)
            #expect(result.unit == metric.unit)
            #expect(result.id == metric.id && result.iconOverride == metric.iconOverride)
            #expect(result.workoutTypeKey == metric.workoutTypeKey && result.isHistorical == metric.isHistorical)
            #expect(MetricDetailHeadline.resolve(metric, stepsValue: nil, stepsUpdated: updated) == metric)
        } else {
            #expect(result == metric)
        }
    }
}
