import Foundation
import Testing
@testable import DUNE

@Suite("WatchWorkoutActivity")
@MainActor
struct WatchWorkoutActivityTests {
    private let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
    private let mirrorID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!

    private func snapshot(
        phase: WatchWorkoutSnapshot.Phase = .running,
        updatedAtOffset: TimeInterval = 10,
        startedAtOffset: TimeInterval = 0,
        elapsedSeconds: TimeInterval = 10
    ) -> WatchWorkoutSnapshot {
        WatchWorkoutSnapshot(
            startedAt: startedAt.addingTimeInterval(startedAtOffset),
            updatedAt: startedAt.addingTimeInterval(updatedAtOffset),
            exerciseName: "Outdoor Run",
            elapsedSeconds: elapsedSeconds,
            phase: phase,
            heartRate: 140,
            activeCalories: 10,
            distanceMeters: 100
        )
    }

    @Test("Requests once, updates the activity, and ends it on finish")
    func startsUpdatesAndFinishes() async {
        let driver = MockWatchWorkoutActivityDriver()
        let activity = WatchWorkoutActivity(driver: driver)
        let initial = snapshot()
        activity.start(mirrorID: mirrorID, snapshot: initial)
        await activity.waitForPendingUpdates()

        #expect(driver.starts.count == 1)
        #expect(driver.starts.first?.mirrorID == mirrorID)
        #expect(driver.starts.first?.snapshot == initial)

        let update = snapshot(updatedAtOffset: 20, elapsedSeconds: 20)
        activity.receive(update, mirrorID: mirrorID)
        await activity.waitForPendingUpdates()

        #expect(driver.updates.map(\.snapshot) == [update])

        let finishDate = startedAt.addingTimeInterval(30)
        activity.finish(mirrorID: mirrorID, at: finishDate)
        await activity.waitForPendingUpdates()

        #expect(driver.events == [
            "start",
            "update-start:activity-1",
            "update-end:activity-1",
            "end:activity-1"
        ])
        #expect(activity.snapshot?.phase == .ended)
        #expect(activity.snapshot?.elapsedSeconds == 30)
    }

    @Test("Adopts the activity requested on HealthKit's background callback without requesting twice")
    func adoptsBackgroundRequest() async {
        let driver = MockWatchWorkoutActivityDriver()
        let activity = WatchWorkoutActivity(driver: driver)
        activity.start(mirrorID: mirrorID, snapshot: snapshot(), requestedID: "background-activity", didRequest: true)
        activity.receive(snapshot(updatedAtOffset: 20, elapsedSeconds: 20), mirrorID: mirrorID)
        await activity.waitForPendingUpdates()
        #expect(driver.starts.isEmpty)
        #expect(driver.updates.first?.id == "background-activity")
        activity.finish(mirrorID: mirrorID, at: startedAt.addingTimeInterval(30))
        await activity.waitForPendingUpdates()
        #expect(driver.events.last == "end:background-activity")
    }

    @Test("Rejects stale timestamps, wrong mirror IDs, and mismatched workout start times")
    func rejectsStaleOrUnrelatedUpdates() async {
        let driver = MockWatchWorkoutActivityDriver()
        let activity = WatchWorkoutActivity(driver: driver)
        let initial = snapshot()
        activity.start(mirrorID: mirrorID, snapshot: initial)
        await activity.waitForPendingUpdates()

        activity.receive(snapshot(updatedAtOffset: 9), mirrorID: mirrorID)
        activity.receive(snapshot(updatedAtOffset: 20), mirrorID: UUID())
        activity.receive(snapshot(updatedAtOffset: 20, startedAtOffset: 2), mirrorID: mirrorID)
        await activity.waitForPendingUpdates()

        #expect(activity.snapshot == initial)
        #expect(driver.updates.isEmpty)
        #expect(driver.starts.count == 1)
    }

    @Test("Does not revive an activity after finish")
    func cannotReviveAfterFinish() async {
        let driver = MockWatchWorkoutActivityDriver()
        let activity = WatchWorkoutActivity(driver: driver)
        activity.start(mirrorID: mirrorID, snapshot: snapshot())
        await activity.waitForPendingUpdates()
        activity.finish(mirrorID: mirrorID, at: startedAt.addingTimeInterval(20))
        await activity.waitForPendingUpdates()

        activity.receive(snapshot(updatedAtOffset: 30), mirrorID: mirrorID)
        await activity.waitForPendingUpdates()

        #expect(activity.snapshot?.phase == .ended)
        #expect(driver.starts.count == 1)
        #expect(driver.updates.isEmpty)
        #expect(driver.events == ["start", "end:activity-1"])
    }

    @Test("A provisional start date is corrected exactly once by the Watch payload")
    func correctsProvisionalStart() async {
        let driver = MockWatchWorkoutActivityDriver()
        let activity = WatchWorkoutActivity(driver: driver)
        activity.start(mirrorID: mirrorID, snapshot: snapshot(), allowsStartCorrection: true)
        let actual = snapshot(updatedAtOffset: 20, startedAtOffset: -60, elapsedSeconds: 80)
        activity.receive(actual, mirrorID: mirrorID, authoritative: true)
        activity.receive(snapshot(updatedAtOffset: 30, startedAtOffset: -120), mirrorID: mirrorID, authoritative: true)
        await activity.waitForPendingUpdates()
        #expect(activity.snapshot == actual)
    }

    @Test("Replaces an activity when a different mirrored session starts")
    func closesReplacedSessionActivity() async {
        let driver = MockWatchWorkoutActivityDriver()
        let activity = WatchWorkoutActivity(driver: driver)
        activity.start(mirrorID: mirrorID, snapshot: snapshot())
        await activity.waitForPendingUpdates()

        let replacementID = UUID()
        let replacement = snapshot(updatedAtOffset: 12)
        activity.start(mirrorID: replacementID, snapshot: replacement)
        await activity.waitForPendingUpdates()

        #expect(driver.events == ["start", "end:activity-1", "start"])
        #expect(driver.starts.count == 2)
        #expect(driver.starts.last?.mirrorID == replacementID)
        #expect(driver.starts.last?.snapshot == replacement)
    }

    @Test("A disabled Live Activity request is attempted only once per session")
    func disabledRequestIsNotRetried() async {
        let driver = MockWatchWorkoutActivityDriver(startBehavior: .disabled)
        let activity = WatchWorkoutActivity(driver: driver)
        activity.start(mirrorID: mirrorID, snapshot: snapshot())
        await activity.waitForPendingUpdates()

        activity.receive(snapshot(updatedAtOffset: 15), mirrorID: mirrorID)
        activity.receive(snapshot(updatedAtOffset: 20), mirrorID: mirrorID)
        await activity.waitForPendingUpdates()

        #expect(driver.starts.count == 1)
        #expect(driver.updates.isEmpty)
        #expect(driver.events == ["start"])
    }

    @Test("A failed Live Activity request is attempted only once per session")
    func failedRequestIsNotRetried() async {
        let driver = MockWatchWorkoutActivityDriver(startBehavior: .throws)
        let activity = WatchWorkoutActivity(driver: driver)
        activity.start(mirrorID: mirrorID, snapshot: snapshot())
        await activity.waitForPendingUpdates()

        activity.receive(snapshot(updatedAtOffset: 15), mirrorID: mirrorID)
        activity.receive(snapshot(updatedAtOffset: 20), mirrorID: mirrorID)
        await activity.waitForPendingUpdates()

        #expect(driver.starts.count == 1)
        #expect(driver.updates.isEmpty)
        #expect(driver.events == ["start"])
    }

    @Test("An in-flight update completes before ending the activity")
    func serializesUpdateBeforeEnd() async {
        let driver = MockWatchWorkoutActivityDriver(blockUpdates: true)
        let activity = WatchWorkoutActivity(driver: driver)
        activity.start(mirrorID: mirrorID, snapshot: snapshot())
        await activity.waitForPendingUpdates()

        activity.receive(snapshot(updatedAtOffset: 20), mirrorID: mirrorID)
        await driver.waitForBlockedUpdate()
        activity.finish(mirrorID: mirrorID, at: startedAt.addingTimeInterval(30))
        driver.releaseBlockedUpdate()
        await activity.waitForPendingUpdates()

        #expect(driver.events == [
            "start",
            "update-start:activity-1",
            "update-end:activity-1",
            "end:activity-1"
        ])
    }

    @Test("Preference refresh follows an in-flight Watch update and never replays stale state")
    func refreshPreferencesKeepsWatchOrdering() async {
        let driver = MockWatchWorkoutActivityDriver(blockUpdates: true)
        let activity = WatchWorkoutActivity(driver: driver)
        activity.start(mirrorID: mirrorID, snapshot: snapshot())
        await activity.waitForPendingUpdates()

        let inFlight = snapshot(updatedAtOffset: 20, elapsedSeconds: 20)
        activity.receive(inFlight, mirrorID: mirrorID)
        await driver.waitForBlockedUpdate()

        activity.refreshPreferences()
        let newest = snapshot(updatedAtOffset: 30, elapsedSeconds: 30)
        activity.receive(newest, mirrorID: mirrorID)
        #expect(activity.snapshot == newest)

        driver.releaseBlockedUpdate()
        await activity.waitForPendingUpdates()

        #expect(driver.updates.map(\.snapshot) == [inFlight, newest])
        #expect(driver.events == [
            "start",
            "update-start:activity-1", "update-end:activity-1",
            "update-start:activity-1", "update-end:activity-1"
        ])
    }

    @Test("Preference refresh does not start an unidentified mirror")
    func refreshPreferencesWaitsForAuthoritativeStart() async {
        let driver = MockWatchWorkoutActivityDriver()
        let activity = WatchWorkoutActivity(driver: driver)
        activity.start(mirrorID: mirrorID, snapshot: snapshot(), allowsStartCorrection: true)
        activity.refreshPreferences()
        await activity.waitForPendingUpdates()
        #expect(driver.starts.isEmpty)
    }

    @Test("A WatchConnectivity terminal snapshot closes the matching activity")
    func terminalContextClosesMatchingWorkout() async {
        let driver = MockWatchWorkoutActivityDriver()
        let activity = WatchWorkoutActivity(driver: driver)
        activity.start(mirrorID: mirrorID, snapshot: snapshot())
        await activity.waitForPendingUpdates()

        let final = snapshot(phase: .ended, updatedAtOffset: 30, elapsedSeconds: 25)
        #expect(activity.finish(matching: final))
        await activity.waitForPendingUpdates()
        activity.receive(snapshot(updatedAtOffset: 40), mirrorID: mirrorID)
        await activity.waitForPendingUpdates()

        #expect(activity.snapshot == final)
        #expect(driver.events == ["start", "end:activity-1"])
    }

    @Test("A delayed end from an older workout cannot dismiss a newer workout")
    func terminalContextCannotEndReplacement() async {
        let driver = MockWatchWorkoutActivityDriver()
        let activity = WatchWorkoutActivity(driver: driver)
        let current = snapshot(updatedAtOffset: 310, startedAtOffset: 300)
        activity.start(mirrorID: UUID(), snapshot: current)
        await activity.waitForPendingUpdates()

        #expect(!activity.finish(matching: snapshot(phase: .ended, updatedAtOffset: 30)))
        await activity.waitForPendingUpdates()

        #expect(activity.snapshot == current)
        #expect(driver.events == ["start"])
    }

    @Test("An end received before the mirror attaches also closes a pre-requested activity")
    func terminalContextBeforeAttachment() async {
        let driver = MockWatchWorkoutActivityDriver()
        let activity = WatchWorkoutActivity(driver: driver)
        let final = snapshot(phase: .ended, updatedAtOffset: 30)
        #expect(!activity.finish(matching: final))

        activity.start(mirrorID: mirrorID, snapshot: snapshot(), requestedID: "background", didRequest: true)
        await activity.waitForPendingUpdates()

        #expect(activity.snapshot == final)
        #expect(driver.starts.isEmpty)
        #expect(driver.events == ["end:background"])
    }

    @Test("Invalid terminal data does not close or mark a workout as ended")
    func rejectsInvalidTerminalContext() async {
        let driver = MockWatchWorkoutActivityDriver()
        let activity = WatchWorkoutActivity(driver: driver)
        let current = snapshot()
        activity.start(mirrorID: mirrorID, snapshot: current)
        await activity.waitForPendingUpdates()
        var invalid = snapshot(phase: .ended)
        invalid.activeCalories = .nan

        #expect(!activity.finish(matching: invalid))
        #expect(!activity.finish(matching: current))
        await activity.waitForPendingUpdates()
        #expect(activity.snapshot == current)
        #expect(driver.events == ["start"])
    }

    @Test("Terminal context is serialized after an in-flight activity update")
    func terminalContextDuringUpdate() async {
        let driver = MockWatchWorkoutActivityDriver(blockUpdates: true)
        let activity = WatchWorkoutActivity(driver: driver)
        activity.start(mirrorID: mirrorID, snapshot: snapshot())
        await activity.waitForPendingUpdates()
        activity.receive(snapshot(updatedAtOffset: 20), mirrorID: mirrorID)
        await driver.waitForBlockedUpdate()

        #expect(activity.finish(matching: snapshot(phase: .ended, updatedAtOffset: 30)))
        driver.releaseBlockedUpdate()
        await activity.waitForPendingUpdates()

        #expect(driver.events == ["start", "update-start:activity-1", "update-end:activity-1", "end:activity-1"])
    }

    @Test("An end cannot close another workout started less than two seconds later")
    func closelySpacedWorkoutsHaveDistinctEnds() async {
        let driver = MockWatchWorkoutActivityDriver()
        let activity = WatchWorkoutActivity(driver: driver)
        let current = snapshot(updatedAtOffset: 5, startedAtOffset: 1)
        activity.start(mirrorID: mirrorID, snapshot: current)
        await activity.waitForPendingUpdates()
        #expect(!activity.finish(matching: snapshot(phase: .ended, updatedAtOffset: 2)))
        await activity.waitForPendingUpdates()
        #expect(activity.snapshot == current)
        #expect(driver.events == ["start"])
    }

    @Test("An unidentified mirror never creates a stranded placeholder activity")
    func defersUnidentifiedStart() async {
        let driver = MockWatchWorkoutActivityDriver()
        let activity = WatchWorkoutActivity(driver: driver)
        activity.start(mirrorID: mirrorID, snapshot: snapshot(), allowsStartCorrection: true)
        await activity.waitForPendingUpdates()
        #expect(driver.starts.isEmpty)

        let identified = snapshot(updatedAtOffset: 20, startedAtOffset: -60, elapsedSeconds: 80)
        activity.receive(identified, mirrorID: mirrorID, authoritative: true)
        await activity.waitForPendingUpdates()
        #expect(driver.starts.map(\.snapshot) == [identified])
    }

    @Test("An end arriving before an unidentified mirror cannot leave a late activity")
    func terminalBeforeUnidentifiedMirror() async {
        let driver = MockWatchWorkoutActivityDriver()
        let activity = WatchWorkoutActivity(driver: driver)
        let final = snapshot(phase: .ended, updatedAtOffset: 30, startedAtOffset: -60)
        #expect(!activity.finish(matching: final))
        activity.start(mirrorID: mirrorID, snapshot: snapshot(updatedAtOffset: 40, startedAtOffset: 40),
                       allowsStartCorrection: true)
        await activity.waitForPendingUpdates()
        #expect(driver.starts.isEmpty)

        activity.receive(snapshot(updatedAtOffset: 20, startedAtOffset: -60), mirrorID: mirrorID, authoritative: true)
        await activity.waitForPendingUpdates()
        #expect(activity.snapshot == final)
        #expect(driver.starts.isEmpty)
    }

    @Test("Multiple terminal events remain available for delayed session attachments")
    func retainsEarlierTerminalIdentity() async {
        let driver = MockWatchWorkoutActivityDriver()
        let activity = WatchWorkoutActivity(driver: driver)
        let firstEnd = snapshot(phase: .ended, updatedAtOffset: 30)
        let secondEnd = snapshot(phase: .ended, updatedAtOffset: 330, startedAtOffset: 300)
        #expect(!activity.finish(matching: firstEnd))
        #expect(!activity.finish(matching: secondEnd))

        activity.start(mirrorID: mirrorID, snapshot: snapshot(), requestedID: "late-first", didRequest: true)
        await activity.waitForPendingUpdates()

        #expect(activity.snapshot == firstEnd)
        #expect(driver.starts.isEmpty)
        #expect(driver.events == ["end:late-first"])
    }
}

@MainActor
private final class MockWatchWorkoutActivityDriver: WatchWorkoutActivityDriving {
    enum StartBehavior {
        case succeeds
        case disabled
        case `throws`
    }

    struct StartCall {
        var mirrorID: UUID
        var snapshot: WatchWorkoutSnapshot
    }

    struct UpdateCall {
        var id: String
        var snapshot: WatchWorkoutSnapshot
    }

    private(set) var starts: [StartCall] = []
    private(set) var updates: [UpdateCall] = []
    private(set) var events: [String] = []
    private let startBehavior: StartBehavior
    private var shouldBlockNextUpdate: Bool
    private var blockedUpdateContinuation: CheckedContinuation<Void, Never>?
    private var updateStartedContinuation: CheckedContinuation<Void, Never>?
    private var updateHasStarted = false

    init(startBehavior: StartBehavior = .succeeds, blockUpdates: Bool = false) {
        self.startBehavior = startBehavior
        shouldBlockNextUpdate = blockUpdates
    }

    func start(mirrorID: UUID, snapshot: WatchWorkoutSnapshot) throws -> String? {
        starts.append(StartCall(mirrorID: mirrorID, snapshot: snapshot))
        events.append("start")
        switch startBehavior {
        case .succeeds:
            return "activity-\(starts.count)"
        case .disabled:
            return nil
        case .throws:
            throw MockError.startFailed
        }
    }

    func update(id: String, snapshot: WatchWorkoutSnapshot) async {
        updates.append(UpdateCall(id: id, snapshot: snapshot))
        events.append("update-start:\(id)")
        updateHasStarted = true
        updateStartedContinuation?.resume()
        updateStartedContinuation = nil

        if shouldBlockNextUpdate {
            shouldBlockNextUpdate = false
            await withCheckedContinuation { blockedUpdateContinuation = $0 }
        }

        events.append("update-end:\(id)")
    }

    func end(id: String) async {
        events.append("end:\(id)")
    }

    func waitForBlockedUpdate() async {
        guard !updateHasStarted else { return }
        await withCheckedContinuation { updateStartedContinuation = $0 }
    }

    func releaseBlockedUpdate() {
        blockedUpdateContinuation?.resume()
        blockedUpdateContinuation = nil
    }

    enum MockError: Error {
        case startFailed
    }
}
