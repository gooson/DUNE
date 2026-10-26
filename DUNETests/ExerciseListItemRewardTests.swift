import Foundation
import Testing
@testable import DUNE

@Suite("ExerciseListItem rewards")
struct ExerciseListItemRewardTests {
    @Test("Manual rows match only their own reward and linked HealthKit workout")
    func manualRewardMatching() {
        let item = makeItem(id: "64D7570E-3343-4471-8A17-8D98725D1617", source: .manual, linkedWorkoutID: "hk-linked")
        let own = makeEvent(id: "own", workoutID: "manual-\(item.id)")
        let linked = makeEvent(id: "linked", workoutID: "hk-linked")
        let unrelated = makeEvent(id: "other", workoutID: "another-workout")

        let matches = item.matchingRewardEvents(in: [own, linked, unrelated])

        #expect(matches.map(\.id) == ["own", "linked"])
    }

    @Test("HealthKit rows cannot borrow a manual workout's reward")
    func healthKitRewardMatching() {
        let item = makeItem(id: "hk-one", source: .healthKit)
        let own = makeEvent(id: "own", workoutID: "hk-one")
        let manual = makeEvent(id: "manual", workoutID: "manual-hk-one")

        #expect(item.matchingRewardEvents(in: [own, manual]).map(\.id) == ["own"])
    }

    @Test("Average heart rate is shown only for finite plausible values")
    func validAverageHeartRate() {
        let cases: [(Double, Int?)] = [
            (.nan, nil), (.infinity, nil), (0, nil), (19, nil),
            (148.4, 148), (300, 300), (301, nil)
        ]
        for (input, expected) in cases {
            let item = makeItem(id: "hk-one", source: .healthKit, heartRateAvg: input)
            #expect(item.validHeartRateAvg == expected)
        }
    }

    private func makeItem(
        id: String,
        source: ExerciseListItem.Source,
        linkedWorkoutID: String? = nil,
        heartRateAvg: Double? = nil
    ) -> ExerciseListItem {
        ExerciseListItem(
            id: id,
            type: "Running",
            duration: 1_800,
            calories: nil,
            distance: nil,
            date: Date(timeIntervalSince1970: 0),
            source: source,
            isLinkedToHealthKit: linkedWorkoutID != nil,
            linkedWorkoutID: linkedWorkoutID,
            heartRateAvg: heartRateAvg
        )
    }

    private func makeEvent(id: String, workoutID: String) -> WorkoutRewardEvent {
        WorkoutRewardEvent(
            id: id,
            workoutID: workoutID,
            activityTypeRawValue: "running",
            date: Date(timeIntervalSince1970: 0),
            kind: .milestone,
            title: "Milestone Reached",
            detail: "5K",
            pointsAwarded: 10,
            levelAfterEvent: nil
        )
    }
}
