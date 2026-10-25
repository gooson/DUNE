import Foundation
import Testing
@testable import DUNE

@Suite("ParsedWatchIncomingMessage")
struct ParsedWatchIncomingMessageTests {
    @Test("Parses requestExerciseLibrarySync flag")
    func parsesRequestFlag() {
        let parsed = ParsedWatchIncomingMessage(from: ["requestExerciseLibrarySync": true])
        #expect(parsed.requestExerciseLibrarySync)
        #expect(!parsed.requestWorkoutTemplateSync)
        #expect(parsed.workoutCompleteData == nil)
        #expect(parsed.setCompletedData == nil)
    }

    @Test("Parses requestWorkoutTemplateSync flag")
    func parsesTemplateRequestFlag() {
        let parsed = ParsedWatchIncomingMessage(from: ["requestWorkoutTemplateSync": true])
        #expect(parsed.requestWorkoutTemplateSync)
        #expect(!parsed.requestExerciseLibrarySync)
        #expect(parsed.workoutCompleteData == nil)
        #expect(parsed.setCompletedData == nil)
    }

    @Test("Parses workoutComplete payload")
    func parsesWorkoutCompletePayload() {
        let payload = Data([0x01, 0x02, 0x03])
        let parsed = ParsedWatchIncomingMessage(from: ["workoutComplete": payload])

        #expect(parsed.workoutCompleteData == payload)
        #expect(parsed.setCompletedData == nil)
        #expect(!parsed.requestExerciseLibrarySync)
        #expect(!parsed.requestWorkoutTemplateSync)
    }

    @Test("Parses setCompleted payload")
    func parsesSetCompletedPayload() {
        let payload = Data([0x0A, 0x0B])
        let parsed = ParsedWatchIncomingMessage(from: ["setCompleted": payload])

        #expect(parsed.setCompletedData == payload)
        #expect(parsed.workoutCompleteData == nil)
        #expect(!parsed.requestExerciseLibrarySync)
        #expect(!parsed.requestWorkoutTemplateSync)
    }

    @Test("Ignores unrelated keys")
    func ignoresUnrelatedKeys() {
        let parsed = ParsedWatchIncomingMessage(from: ["foo": "bar", "count": 1])
        #expect(parsed.workoutCompleteData == nil)
        #expect(parsed.setCompletedData == nil)
        #expect(!parsed.requestExerciseLibrarySync)
        #expect(!parsed.requestWorkoutTemplateSync)
    }

    @Test("Parses active watch workout context")
    func parsesActiveWatchWorkoutContext() {
        let parsed = ParsedWatchIncomingContext(
            from: [
                "watchWorkoutActive": true,
                "watchWorkoutTemplateName": "Leg Day"
            ]
        )

        #expect(parsed.watchWorkoutActive == true)
        #expect(parsed.watchWorkoutTemplateName == "Leg Day")
    }

    @Test("Parses ended watch workout context")
    func parsesEndedWatchWorkoutContext() {
        let parsed = ParsedWatchIncomingContext(
            from: [
                "watchWorkoutActive": false
            ]
        )

        #expect(parsed.watchWorkoutActive == false)
        #expect(parsed.watchWorkoutTemplateName == nil)
    }

    @Test("Parses the same validated terminal snapshot from background and immediate delivery")
    func terminalSnapshotDelivery() throws {
        let snapshot = terminalSnapshot()
        let data = try JSONEncoder().encode(snapshot)
        let context: [String: Any] = ["watchWorkoutActive": false, "watchWorkoutEndedSnapshot": data,
                                     "watchWorkoutUpdatedAt": snapshot.updatedAt.timeIntervalSince1970]
        #expect(ParsedWatchIncomingContext(from: context).watchWorkoutEndedSnapshot == snapshot)
        #expect(ParsedWatchIncomingMessage(from: context).workoutContext.watchWorkoutEndedSnapshot == snapshot)
        #expect(ParsedWatchIncomingContext(from: context).watchWorkoutUpdatedAt == snapshot.updatedAt)
    }

    @Test("Malformed, oversized, invalid, or nonterminal snapshots cannot dismiss an activity")
    func rejectsUnsafeTerminalSnapshot() throws {
        var invalid = terminalSnapshot()
        invalid.elapsedSeconds = -1
        var running = terminalSnapshot()
        running.phase = .running
        for data in [Data([0xFF]), Data(repeating: 0, count: 4_097),
                     try JSONEncoder().encode(invalid), try JSONEncoder().encode(running)] {
            let parsed = ParsedWatchIncomingContext(from: ["watchWorkoutActive": false, "watchWorkoutEndedSnapshot": data])
            #expect(parsed.watchWorkoutEndedSnapshot == nil)
        }
        let data = try JSONEncoder().encode(terminalSnapshot())
        #expect(ParsedWatchIncomingContext(from: ["watchWorkoutActive": true, "watchWorkoutEndedSnapshot": data]).watchWorkoutEndedSnapshot == nil)
        #expect(ParsedWatchIncomingContext(from: ["watchWorkoutEndedSnapshot": data]).watchWorkoutEndedSnapshot == nil)
    }

    private func terminalSnapshot() -> WatchWorkoutSnapshot {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        return WatchWorkoutSnapshot(startedAt: start, updatedAt: start.addingTimeInterval(60),
                                    exerciseName: "Chest Press", elapsedSeconds: 60, phase: .ended,
                                    heartRate: 102, activeCalories: 3, distanceMeters: 0)
    }
}
