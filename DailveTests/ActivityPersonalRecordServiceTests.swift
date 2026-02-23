import Foundation
import Testing
@testable import Dailve

@Suite("ActivityPersonalRecordService")
struct ActivityPersonalRecordServiceTests {

    @Test("Merges strength and HealthKit cardio records")
    func mergesStrengthAndCardio() {
        let strength = [
            StrengthPersonalRecord(
                exerciseName: "Bench Press",
                maxWeight: 100,
                date: Date(),
                referenceDateForRecent: Date()
            ),
        ]

        let cardio: [WorkoutActivityType: [PersonalRecordType: PersonalRecord]] = [
            .running: [
                .longestDistance: PersonalRecord(
                    type: .longestDistance,
                    value: 12_000,
                    date: Date(),
                    workoutID: "hk-1"
                ),
            ],
        ]

        let result = ActivityPersonalRecordService.merge(
            strengthRecords: strength,
            cardioRecordsByActivity: cardio,
            manualCardioEntries: []
        )

        #expect(result.contains { $0.kind == .strengthWeight })
        #expect(result.contains { $0.kind == .longestDistance && $0.source == .healthKit })
    }

    @Test("Uses HealthKit-first policy for cardio kind")
    func healthKitFirstPolicy() {
        let cardio: [WorkoutActivityType: [PersonalRecordType: PersonalRecord]] = [
            .running: [
                .longestDistance: PersonalRecord(
                    type: .longestDistance,
                    value: 10_000,
                    date: Date(),
                    workoutID: "hk-1"
                ),
            ],
        ]

        let manual = [
            ActivityPersonalRecordService.ManualCardioEntry(
                title: "Manual Run",
                date: Date(),
                duration: 3600,
                distanceMeters: 15_000,
                calories: 700
            ),
        ]

        let result = ActivityPersonalRecordService.merge(
            strengthRecords: [],
            cardioRecordsByActivity: cardio,
            manualCardioEntries: manual
        )

        let distanceRecords = result.filter { $0.kind == .longestDistance }
        #expect(distanceRecords.count == 1)
        #expect(distanceRecords.first?.source == .healthKit)
        #expect(distanceRecords.first?.value == 10_000)
    }

    @Test("Builds manual cardio fallback when HealthKit cardio is absent")
    func manualFallbackWhenNoHealthKit() {
        let manual = [
            ActivityPersonalRecordService.ManualCardioEntry(
                title: "Manual Run",
                date: Date(),
                duration: 3_000,
                distanceMeters: 8_000,
                calories: 500
            ),
        ]

        let result = ActivityPersonalRecordService.merge(
            strengthRecords: [],
            cardioRecordsByActivity: [:],
            manualCardioEntries: manual
        )

        #expect(result.contains { $0.kind == .longestDistance && $0.source == .manual })
        #expect(result.contains { $0.kind == .longestDuration && $0.source == .manual })
        #expect(result.contains { $0.kind == .highestCalories && $0.source == .manual })
        #expect(result.contains { $0.kind == .fastestPace && $0.source == .manual })
    }

    @Test("Pace fallback keeps lower value as better")
    func paceLowerIsBetter() {
        let now = Date()
        let manual = [
            ActivityPersonalRecordService.ManualCardioEntry(
                title: "Slow Run",
                date: now,
                duration: 2_100,          // 7:00/km for 5km
                distanceMeters: 5_000,
                calories: 350
            ),
            ActivityPersonalRecordService.ManualCardioEntry(
                title: "Fast Run",
                date: now,
                duration: 1_500,          // 5:00/km for 5km
                distanceMeters: 5_000,
                calories: 400
            ),
        ]

        let result = ActivityPersonalRecordService.merge(
            strengthRecords: [],
            cardioRecordsByActivity: [:],
            manualCardioEntries: manual
        )

        let fastestPace = result.first { $0.kind == .fastestPace }
        #expect(fastestPace != nil)
        #expect(fastestPace?.value == 300) // seconds per km
        #expect(fastestPace?.title == "Fast Run")
    }
}
