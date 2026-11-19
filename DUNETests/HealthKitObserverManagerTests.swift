import Foundation
import HealthKit
import SwiftData
import Synchronization
import Testing
import UserNotifications
@testable import DUNE

@Suite("HealthKitObserverManager")
struct HealthKitObserverManagerTests {
    @Test("Authorization retry re-enables failed delivery without duplicating queries")
    @MainActor
    func retriesDeliveryAfterAuthorization() {
        let store = ObserverStoreSpy()
        store.state.withLock { $0.deliverySucceeds = false }
        let manager = HealthKitObserverManager(store: store, coordinator: ObserverRefreshStub())
        manager.startObserving()
        #expect(store.state.withLock { $0.deliveryAttempts } == 9)

        store.state.withLock { $0.deliverySucceeds = true }
        manager.startObserving()
        #expect(store.state.withLock { $0.deliveryAttempts } == 18)
        #expect(store.state.withLock { $0.successfulDeliveries } == 9)
        #expect(store.state.withLock { $0.executed.count } == 9)
        manager.stopObserving()
    }

    @Test("Launch registration is synchronous, idempotent, and fully stopped before restart")
    @MainActor
    func registrationLifecycle() {
        let store = ObserverStoreSpy()
        let manager = HealthKitObserverManager(store: store, coordinator: ObserverRefreshStub())

        manager.startObserving()
        let initialQueries = store.state.withLock { $0.executed }
        #expect(initialQueries.count == 9)
        manager.startObserving()
        #expect(store.state.withLock { $0.executed.count } == 9)
        #expect(store.state.withLock { $0.frequencies.count } == 9)

        manager.stopObserving()
        #expect(store.state.withLock { $0.stopped.map(ObjectIdentifier.init) } == initialQueries.map(ObjectIdentifier.init))
        manager.stopObserving()
        #expect(store.state.withLock { $0.stopped.count } == 9)

        manager.startObserving()
        #expect(store.state.withLock { $0.executed.count } == 18)
        manager.stopObserving()
        #expect(store.state.withLock { $0.stopped.count } == 18)
    }

    @Test("Body composition and workouts request immediate delivery while steps remain hourly")
    @MainActor
    func bodyCompositionDeliveryFrequency() {
        let store = ObserverStoreSpy()
        let manager = HealthKitObserverManager(store: store, coordinator: ObserverRefreshStub())
        manager.startObserving()
        let frequencies = store.state.withLock { $0.frequencies }
        for identifier: HKQuantityTypeIdentifier in [.bodyMass, .bodyFatPercentage, .bodyMassIndex] {
            #expect(frequencies[HKQuantityType(identifier).identifier] == .immediate)
        }
        #expect(frequencies[HKQuantityType(.heartRate).identifier] == .immediate)
        #expect(frequencies[HKQuantityType(.stepCount).identifier] == .hourly)
        #expect(frequencies[HKSampleType.workoutType().identifier] == .immediate)
        manager.stopObserving()
    }

    @Test("Observer completion waits for asynchronous work and fires once", arguments: [false, true])
    func completionWaits(cancel: Bool) async {
        let gate = ObserverWorkGate()
        let completions = Mutex(0)
        let task = HealthKitObserverManager.processUpdate(completion: {
            completions.withLock { $0 += 1 }
        }) {
            await gate.wait()
        }
        await gate.waitUntilStarted()
        #expect(completions.withLock { $0 } == 0)
        if cancel { task.cancel() }
        #expect(completions.withLock { $0 } == 0)
        await gate.release()
        await task.value
        #expect(completions.withLock { $0 } == 1)
    }

    @Test("A change to last week's workout invalidates Life history and access changes clear it immediately")
    @MainActor
    func rechecksPastWorkouts() async throws {
        let now = Date()
        let sunday = LifeAutoAchievementService.weekStart(containing: now).addingTimeInterval(-3600)
        let run = WorkoutSummary(id: "sunday", type: "Running", activityType: .running,
                                 duration: 1800, calories: nil, distance: 5000, date: sunday)
        let source = EditableWorkoutSource(workouts: [run])
        let history = LifeHealthKitWorkouts(service: source)
        #expect(await history.refresh(now: now))
        #expect(history.workouts.map(\.id) == ["sunday"])
        await source.replace(with: [])
        history.invalidateWorkoutHistory()
        #expect(await history.refresh(now: now))
        #expect(history.workouts.isEmpty)

        await source.replace(with: [run])
        history.invalidateWorkoutHistory()
        #expect(await history.refresh(now: now))
        history.invalidateWorkoutHistory(discardCached: true)
        #expect(history.workouts.isEmpty)
    }

    @Test("Workout access changes discard pending and cached reminder dates")
    @MainActor
    func discardsReminderDateAfterWorkoutAccessChange() async {
        let now = Date()
        let workoutDate = now.addingTimeInterval(-3600)
        let run = WorkoutSummary(id: "access-change-run", type: "Running", activityType: .running,
                                 duration: 1800, calories: nil, distance: nil, date: workoutDate)
        let source = EditableWorkoutSource(workouts: [run])
        let health = LifeHealthKitWorkouts(service: source)
        #expect(await health.refreshReminderHealthWorkoutDate(before: now))
        #expect(health.reminderHealthWorkoutSource == .resolved(workoutDate))
        health.invalidateWorkoutHistory(discardCached: true)
        #expect(health.reminderHealthWorkoutSource == .pending)

        let oldAccess = health.reminderAccessGeneration
        let gate = ObserverWorkGate()
        await source.pauseNextReminderRead(on: gate)
        let oldLookup = Task { await health.refreshReminderHealthWorkoutDate(before: now) }
        await gate.waitUntilStarted()
        health.invalidateWorkoutHistory(discardCached: true)
        #expect(health.reminderAccessGeneration != oldAccess)
        #expect(health.reminderHealthWorkoutSource == .pending)

        await source.replace(with: [])
        await gate.release()
        #expect(await oldLookup.value == false)
        #expect(health.reminderHealthWorkoutSource == .pending)
        #expect(await health.refreshReminderHealthWorkoutDate(before: now))
        #expect(health.reminderHealthWorkoutSource == .resolved(nil))
    }

    @Test("The workout observer retries once when backgrounding invalidates its reminder read")
    @MainActor
    func retriesWorkoutReminderAfterBackgrounding() async throws {
        let container = try ModelContainer(for: HabitDefinition.self, HabitLog.self, ExerciseRecord.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let habit = HabitDefinition(name: "Workout", iconCategory: .fitness, habitType: .check,
                                   goalValue: 1, goalUnit: nil, frequency: .daily,
                                   isAutoLinked: true, autoLinkSource: "exercise")
        context.insert(habit)
        try context.save()

        let run = WorkoutSummary(id: "backgrounded-run", type: "Running", activityType: .running,
                                 duration: 1800, calories: nil, distance: nil, date: Date())
        let source = EditableWorkoutSource(workouts: [run])
        let health = LifeHealthKitWorkouts(service: source)
        let gate = ObserverWorkGate()
        await source.pauseNextReminderRead(on: gate)
        let client = ObserverHabitNotificationClient()
        let scheduler = HabitReminderScheduler(client: client)
        let completions = Mutex(0)
        let task = HealthKitObserverManager.handleObserverUpdate(
            sampleType: HKSampleType.workoutType(), error: nil, coordinator: ObserverRefreshStub(),
            notificationEvaluator: nil, watchReminder: ObserverWatchReminderSpy(gate: ObserverWorkGate()),
            refreshExerciseReminders: {
                await health.refreshReminders(in: container.mainContext, scheduler: scheduler)
            },
            completion: { @Sendable in completions.withLock { $0 += 1 } }
        )

        await gate.waitUntilStarted()
        health.invalidateWorkoutHistory(discardCached: true)
        await source.replace(with: [])
        #expect(completions.withLock { $0 } == 0)

        await gate.release()
        await task?.value

        #expect(await source.reminderReadCount == 2)
        #expect(health.reminderHealthWorkoutSource == .resolved(nil))
        #expect(client.requests.count == 1)
        #expect(client.requests.first?.trigger?.repeats == true)
        #expect(completions.withLock { $0 } == 1)
    }

    @Test("Workout delivery waits for linked habit reminders before acknowledging HealthKit")
    func workoutRechecksHabitReminders() async {
        let gate = ObserverWorkGate()
        let completions = Mutex(0)
        let task = HealthKitObserverManager.handleObserverUpdate(
            sampleType: HKSampleType.workoutType(), error: nil, coordinator: ObserverRefreshStub(),
            notificationEvaluator: nil, watchReminder: await ObserverWatchReminderSpy(gate: ObserverWorkGate()),
            refreshExerciseReminders: { await gate.wait() },
            completion: { completions.withLock { $0 += 1 } }
        )
        await gate.waitUntilStarted()
        #expect(completions.withLock { $0 } == 0)
        await gate.release()
        await task?.value
        #expect(completions.withLock { $0 } == 1)
    }

    @Test("Heart-rate update completes after the Watch reminder is rechecked")
    func heartRateUpdateRechecksWatchReminder() async {
        let gate = ObserverWorkGate()
        let watchReminder = await ObserverWatchReminderSpy(gate: gate)
        let completions = Mutex(0)

        let task = HealthKitObserverManager.handleObserverUpdate(
            sampleType: HKQuantityType(.heartRate),
            error: nil,
            coordinator: ObserverRefreshStub(),
            notificationEvaluator: nil,
            watchReminder: watchReminder,
            completion: { completions.withLock { $0 += 1 } }
        )

        await gate.waitUntilStarted()
        #expect(await watchReminder.recheckCount == 1)
        #expect(completions.withLock { $0 } == 0)

        await gate.release()
        await task?.value
        #expect(completions.withLock { $0 } == 1)
    }
}

@MainActor
private final class ObserverWatchReminderSpy: WatchBedtimeReminderRechecking {
    let gate: ObserverWorkGate
    private(set) var recheckCount = 0

    init(gate: ObserverWorkGate) {
        self.gate = gate
    }

    func cancelPendingReminderIfWatchIsWorn() async {
        recheckCount += 1
        await gate.wait()
    }
}

private final class ObserverStoreSpy: HealthKitObserverStoring {
    struct State {
        var executed: [HKQuery] = []
        var stopped: [HKQuery] = []
        var frequencies: [String: HKUpdateFrequency] = [:]
        var deliverySucceeds = true
        var deliveryAttempts = 0
        var successfulDeliveries = 0
    }

    let state = Mutex(State())

    func execute(_ query: HKQuery) {
        state.withLock { $0.executed.append(query) }
    }

    func stop(_ query: HKQuery) {
        state.withLock { $0.stopped.append(query) }
    }

    func enableBackgroundDelivery(
        for type: HKObjectType,
        frequency: HKUpdateFrequency,
        withCompletion completion: @escaping @Sendable (Bool, Error?) -> Void
    ) {
        let success = state.withLock {
            $0.frequencies[type.identifier] = frequency
            $0.deliveryAttempts += 1
            if $0.deliverySucceeds { $0.successfulDeliveries += 1 }
            return $0.deliverySucceeds
        }
        completion(success, success ? nil : NSError(domain: HKErrorDomain, code: HKError.errorAuthorizationDenied.rawValue))
    }
}

private struct ObserverRefreshStub: AppRefreshCoordinating {
    func requestRefresh(source: RefreshSource) async -> Bool { false }
    func forceRefresh() async {}
    func invalidateCacheOnly() async {}
    func makeRefreshStream() async -> AsyncStream<RefreshSource> {
        AsyncStream { $0.finish() }
    }
}

private actor ObserverWorkGate {
    private var work: CheckedContinuation<Void, Never>?
    private var started: CheckedContinuation<Void, Never>?

    func wait() async {
        await withCheckedContinuation { continuation in
            work = continuation
            started?.resume()
            started = nil
        }
    }

    func waitUntilStarted() async {
        if work != nil { return }
        await withCheckedContinuation { started = $0 }
    }

    func release() {
        work?.resume()
        work = nil
    }
}

@MainActor
private final class ObserverHabitNotificationClient: HabitReminderNotificationScheduling {
    private(set) var requests: [UNNotificationRequest] = []

    func pendingNotificationRequests() async -> [UNNotificationRequest] { requests }
    func add(_ request: UNNotificationRequest) async throws { requests.append(request) }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        requests.removeAll { identifiers.contains($0.identifier) }
    }
}

private actor EditableWorkoutSource: WorkoutQuerying {
    private var workouts: [WorkoutSummary]
    private var nextReminderReadGate: ObserverWorkGate?
    private(set) var reminderReadCount = 0

    init(workouts: [WorkoutSummary]) { self.workouts = workouts }
    func replace(with workouts: [WorkoutSummary]) { self.workouts = workouts }
    func pauseNextReminderRead(on gate: ObserverWorkGate) { nextReminderReadGate = gate }

    func latestWorkoutDate(before date: Date, excludingIDs: Set<String>) async throws -> Date? {
        reminderReadCount += 1
        let result = workouts.filter { $0.date <= date && $0.duration > 0 && !excludingIDs.contains($0.id) }
            .map(\.date).max()
        if let gate = nextReminderReadGate {
            nextReminderReadGate = nil
            await gate.wait()
        }
        return result
    }

    func fetchWorkouts(days: Int) async throws -> [WorkoutSummary] { workouts }
    func fetchWorkouts(start: Date, end: Date) async throws -> [WorkoutSummary] {
        workouts.filter { $0.date >= start && $0.date <= end }
    }
}
