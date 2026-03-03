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
}
