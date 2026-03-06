import Foundation
import Testing
@testable import DUNEWatch

@Suite("WatchDeleteRequestPolicy")
struct WatchDeleteRequestPolicyTests {
    @Test("Processes first delete request")
    func processesFirstRequest() {
        let workoutUUID = UUID()
        let now = Date()
        var processed: [UUID: Date] = [:]

        let shouldProcess = WatchDeleteRequestPolicy.shouldProcess(
            workoutUUID: workoutUUID,
            at: now,
            processedAtByWorkoutID: &processed
        )

        #expect(shouldProcess)
        #expect(processed[workoutUUID] == now)
    }

    @Test("Skips duplicate requests within dedupe window")
    func skipsDuplicateRequestWithinWindow() {
        let workoutUUID = UUID()
        let now = Date()
        var processed: [UUID: Date] = [
            workoutUUID: now.addingTimeInterval(-5)
        ]

        let shouldProcess = WatchDeleteRequestPolicy.shouldProcess(
            workoutUUID: workoutUUID,
            at: now,
            processedAtByWorkoutID: &processed,
            dedupeWindow: 30
        )

        #expect(!shouldProcess)
    }

    @Test("Allows duplicate requests after dedupe window")
    func allowsDuplicateRequestAfterWindow() {
        let workoutUUID = UUID()
        let now = Date()
        var processed: [UUID: Date] = [
            workoutUUID: now.addingTimeInterval(-31)
        ]

        let shouldProcess = WatchDeleteRequestPolicy.shouldProcess(
            workoutUUID: workoutUUID,
            at: now,
            processedAtByWorkoutID: &processed,
            dedupeWindow: 30
        )

        #expect(shouldProcess)
        #expect(processed[workoutUUID] == now)
    }
}
