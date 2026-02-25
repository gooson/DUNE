import Foundation
import Testing
@testable import DUNE

@Suite("CheckInjuryConflictUseCase")
struct CheckInjuryConflictUseCaseTests {
    let useCase = CheckInjuryConflictUseCase()

    @Test("no conflicts when no injuries")
    func noInjuries() {
        let result = useCase.execute(input: .init(
            exerciseMuscles: [.chest, .shoulders],
            activeInjuries: []
        ))
        #expect(result.conflicts.isEmpty)
        #expect(result.hasConflict == false)
        #expect(result.maxSeverity == nil)
    }

    @Test("no conflicts when muscles don't overlap")
    func noOverlap() {
        let injury = InjuryInfo(
            id: UUID(),
            bodyPart: .knee,
            bodySide: .left,
            severity: .moderate,
            startDate: Date(),
            endDate: nil,
            memo: ""
        )
        let result = useCase.execute(input: .init(
            exerciseMuscles: [.chest, .biceps],
            activeInjuries: [injury]
        ))
        #expect(result.conflicts.isEmpty)
        #expect(result.hasConflict == false)
    }

    @Test("detects conflict when muscles overlap")
    func overlappingMuscles() {
        // knee affects quadriceps
        let injury = InjuryInfo(
            id: UUID(),
            bodyPart: .knee,
            bodySide: .left,
            severity: .severe,
            startDate: Date(),
            endDate: nil,
            memo: ""
        )
        let result = useCase.execute(input: .init(
            exerciseMuscles: [.quadriceps, .glutes],
            activeInjuries: [injury]
        ))
        #expect(result.hasConflict == true)
        #expect(result.conflicts.count == 1)
        #expect(result.maxSeverity == .severe)
        #expect(result.conflicts.first?.conflictingMuscles.contains(.quadriceps) == true)
    }

    @Test("multiple injuries produce multiple conflicts")
    func multipleConflicts() {
        let kneeInjury = InjuryInfo(
            id: UUID(),
            bodyPart: .knee,
            bodySide: .left,
            severity: .moderate,
            startDate: Date(),
            endDate: nil,
            memo: ""
        )
        let shoulderInjury = InjuryInfo(
            id: UUID(),
            bodyPart: .shoulder,
            bodySide: .right,
            severity: .severe,
            startDate: Date(),
            endDate: nil,
            memo: ""
        )
        let result = useCase.execute(input: .init(
            exerciseMuscles: [.quadriceps, .shoulders, .chest],
            activeInjuries: [kneeInjury, shoulderInjury]
        ))
        #expect(result.hasConflict == true)
        #expect(result.conflicts.count == 2)
        #expect(result.maxSeverity == .severe)
    }

    @Test("inactive injuries are filtered out")
    func inactiveInjuriesIgnored() {
        let endedInjury = InjuryInfo(
            id: UUID(),
            bodyPart: .knee,
            bodySide: .left,
            severity: .severe,
            startDate: Date().addingTimeInterval(-86400 * 30),
            endDate: Date().addingTimeInterval(-86400),
            memo: ""
        )
        let result = useCase.execute(input: .init(
            exerciseMuscles: [.quadriceps],
            activeInjuries: [endedInjury]
        ))
        // The use case filters by isActive, so ended injuries should not conflict
        #expect(result.hasConflict == false)
    }
}
