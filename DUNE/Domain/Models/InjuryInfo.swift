import Foundation

/// Domain-level DTO for injury data exchange between layers.
/// Does not depend on SwiftData or SwiftUI.
struct InjuryInfo: Identifiable, Sendable, Hashable {
    let id: UUID
    let bodyPart: BodyPart
    let bodySide: BodySide?
    let severity: InjurySeverity
    let startDate: Date
    let endDate: Date?
    let memo: String

    var isActive: Bool { endDate == nil }

    /// Days since injury started (or total duration if ended).
    var durationDays: Int {
        let end = endDate ?? Date()
        return Swift.max(0, Calendar.current.dateComponents([.day], from: startDate, to: end).day ?? 0)
    }

    /// All muscle groups affected by this injury.
    var affectedMuscleGroups: [MuscleGroup] { bodyPart.affectedMuscleGroups }
}
