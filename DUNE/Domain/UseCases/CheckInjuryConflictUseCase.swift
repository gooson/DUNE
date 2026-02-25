import Foundation

/// Conflict between an exercise and an active injury.
struct InjuryConflict: Sendable, Identifiable {
    var id: UUID { injury.id }
    let injury: InjuryInfo
    let conflictingMuscles: [MuscleGroup]

    /// Highest severity among conflicting injuries determines the warning level.
    var severity: InjurySeverity { injury.severity }
}

protocol InjuryConflictChecking: Sendable {
    func execute(input: CheckInjuryConflictUseCase.Input) -> CheckInjuryConflictUseCase.Output
}

/// Checks if an exercise conflicts with any active injuries.
/// Pure synchronous computation — no SwiftUI or SwiftData dependency.
struct CheckInjuryConflictUseCase: InjuryConflictChecking, Sendable {

    struct Input: Sendable {
        let exerciseMuscles: [MuscleGroup]
        let activeInjuries: [InjuryInfo]
    }

    struct Output: Sendable {
        let conflicts: [InjuryConflict]

        var hasConflict: Bool { !conflicts.isEmpty }

        /// Highest severity among all conflicts.
        var maxSeverity: InjurySeverity? {
            conflicts.map(\.severity).max()
        }
    }

    func execute(input: Input) -> Output {
        guard !input.exerciseMuscles.isEmpty, !input.activeInjuries.isEmpty else {
            return Output(conflicts: [])
        }

        let exerciseMuscleSet = Set(input.exerciseMuscles)
        var conflicts: [InjuryConflict] = []

        for injury in input.activeInjuries where injury.isActive {
            let injuredMuscles = Set(injury.affectedMuscleGroups)
            let overlap = exerciseMuscleSet.intersection(injuredMuscles)
            if !overlap.isEmpty {
                conflicts.append(InjuryConflict(
                    injury: injury,
                    conflictingMuscles: Array(overlap).sorted { $0.rawValue < $1.rawValue }
                ))
            }
        }

        return Output(conflicts: conflicts)
    }
}
