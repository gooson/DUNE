import Foundation
import Testing
@testable import DUNE

@Suite("Health query intent contract")
struct HealthQueryIntentContractTests {
    @Test("Every typed Siri query maps to the shared query kind")
    func allKindsMapToDomain() {
        #expect(HealthQueryIntentKind.allCases.count == HealthQueryKind.allCases.count)
        for intentKind in HealthQueryIntentKind.allCases {
            #expect(intentKind.queryKind.rawValue == intentKind.rawValue)
        }
    }

    @Test("Typed query preserves selected periods and record context")
    func requestPreservesContext() {
        var intent = QueryHealthInformationIntent(.workoutComparison)
        intent.period = .thisWeek
        intent.comparisonPeriod = .lastWeek
        intent.exercise = HealthExerciseEntity(id: "squat", name: "Squat")
        intent.workout = HealthWorkoutEntity(id: "app:123", name: "Workout")
        intent.searchText = "  hill repeats  "

        let now = Date(timeIntervalSince1970: 1_767_225_600)
        let request = intent.makeRequest(now: now, calendar: Calendar(identifier: .gregorian))

        #expect(request.kind == .workoutComparison)
        #expect(request.interval == HealthQueryPeriod.thisWeek.interval(endingAt: now, calendar: Calendar(identifier: .gregorian)))
        #expect(request.comparisonInterval == HealthQueryPeriod.lastWeek.interval(endingAt: now, calendar: Calendar(identifier: .gregorian)))
        #expect(request.exerciseID == "squat")
        #expect(request.workoutID == "app:123")
        #expect(request.searchText == "hill repeats")
    }
}

@Suite("Transient health answer retention")
@MainActor
struct HealthQueryIntentStateTests {
    @Test("Evicts oldest answer and clears retained health data")
    func boundedRetentionAndClear() {
        let state = HealthQueryIntentState()
        let interval = DateInterval(start: .now.addingTimeInterval(-60), end: .now)
        var ids: [String] = []
        for index in 0..<9 {
            let result = HealthQueryResult(
                kind: .latestWorkout, status: .available, title: "Result \(index)",
                generatedAt: .now, interval: interval, spokenSummary: "Value \(index)"
            )
            ids.append(state.retain(result).id)
        }
        #expect(state.result(for: ids[0]) == nil)
        #expect(state.result(for: ids[1])?.spokenSummary == "Value 1")

        state.clear()
        #expect(state.answer(for: ids[1]) == nil)
        #expect(state.result(for: ids[8]) == nil)
    }
}
