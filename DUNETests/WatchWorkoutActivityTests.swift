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
    private let blockUpdates: Bool
    private var blockedUpdateContinuation: CheckedContinuation<Void, Never>?
    private var updateStartedContinuation: CheckedContinuation<Void, Never>?
    private var updateHasStarted = false

    init(startBehavior: StartBehavior = .succeeds, blockUpdates: Bool = false) {
        self.startBehavior = startBehavior
        self.blockUpdates = blockUpdates
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

        if blockUpdates {
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
