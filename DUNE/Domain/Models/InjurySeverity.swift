import Foundation

/// 3-level injury severity scale.
enum InjurySeverity: Int, Codable, CaseIterable, Sendable, Comparable, Identifiable, Hashable {
    var id: Int { rawValue }

    case minor = 1     // Can train with caution
    case moderate = 2  // Avoid exercises for affected area
    case severe = 3    // No exercises for affected area

    static func < (lhs: InjurySeverity, rhs: InjurySeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
