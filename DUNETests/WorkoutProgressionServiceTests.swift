import Foundation
import Testing
@testable import DUNE

@Suite("WorkoutProgressionService")
struct WorkoutProgressionServiceTests {
    private let service = WorkoutProgressionService()

    private func set(
        weight: Double = 60, reps: Int = 10, target: Int? = 10,
        rpe: Double? = 8, source: String? = "user", type: SetType = .working,
        completed: Bool = true
    ) -> ProgressionSetInput {
        .init(weight: weight, reps: reps, plannedReps: target, rpe: rpe,
              rpeSourceRaw: source, setType: type, isCompleted: completed)
    }

    @Test("Achieving reps does not raise the next set weight")
    func withinSessionMaintains() {
        #expect(service.nextSet(after: set(), incrementKg: 2.5)?.weight == 60)
    }

    @Test("High effort or missed plan offers a bounded reduction")
    func reduction() {
        #expect(service.nextSet(after: set(rpe: 10), incrementKg: 2.5) == .init(weight: 55, reason: .highEffort))
        #expect(service.nextSet(after: set(reps: 6), incrementKg: 2.5) == .init(weight: 55, reason: .missedTarget))
        #expect(service.nextSet(after: set(weight: 5, rpe: 10), incrementKg: 2.5)?.weight == 5)
    }

    @Test("Only complete confirmed plans qualify for next-session progression")
    func completedPlan() {
        #expect(service.nextSession(sets: [set(), set()], plannedSetCount: 2, incrementKg: 2.5)?.weight == 62.5)
        #expect(service.nextSession(sets: [set()], plannedSetCount: 2, incrementKg: 2.5)?.weight == 60)
        #expect(service.nextSession(sets: [set(completed: false)], plannedSetCount: 1, incrementKg: 2.5)?.weight == 60)
    }

    @Test("Legacy or estimated effort never qualifies for an increase")
    func provenance() {
        for input in [set(target: nil), set(rpe: nil), set(source: nil), set(source: "estimated"), set(source: "future")] {
            #expect(service.nextSession(sets: [input], plannedSetCount: 1, incrementKg: 2.5)?.weight == 60)
        }
        #expect(service.nextSession(sets: [set()], plannedSetCount: nil, incrementKg: 2.5)?.weight == 60)
    }

    @Test("Missed targets and high effort block next-session increases")
    func failure() {
        #expect(service.nextSession(sets: [set(reps: 9)], plannedSetCount: 1, incrementKg: 2.5)?.reason == .missedTarget)
        #expect(service.nextSession(sets: [set(rpe: 8.5)], plannedSetCount: 1, incrementKg: 2.5)?.reason == .highEffort)
    }

    @Test("Warmups are excluded, failure and drop sets block progression")
    func setTypes() {
        #expect(service.nextSession(sets: [set(rpe: nil, type: .warmup), set()], plannedSetCount: 2, incrementKg: 2.5)?.weight == 62.5)
        for type in [SetType.failure, .drop] {
            #expect(service.nextSession(sets: [set(), set(type: type)], plannedSetCount: 2, incrementKg: 2.5)?.weight == 60)
        }
        #expect(service.nextSet(after: set(type: .warmup), incrementKg: 2.5) == nil)
    }

    @Test("Plate rounding never exceeds the ten-percent increase cap")
    func rounding() {
        for weight in [1.0, 5, 8, 12, 20, 23, 60, 499, 500] {
            let result = service.nextSession(sets: [set(weight: weight)], plannedSetCount: 1, incrementKg: 5)
            #expect((result?.weight ?? 0) <= weight * 1.1 + 1e-9)
            #expect((result?.weight ?? 0) >= weight)
            #expect((result?.weight ?? 0) <= 500)
        }
    }

    @Test("Invalid numeric inputs cannot produce recommendations")
    func invalidInputs() {
        for weight in [Double.nan, .infinity, -1, 0, 501] {
            #expect(service.nextSet(after: set(weight: weight), incrementKg: 2.5) == nil)
        }
        for increment in [Double.nan, .infinity, -1, 0, 6] {
            #expect(service.nextSession(sets: [set()], plannedSetCount: 1, incrementKg: increment) == nil)
        }
        #expect(service.nextSession(sets: [], plannedSetCount: 0, incrementKg: 2.5) == nil)
    }
}
