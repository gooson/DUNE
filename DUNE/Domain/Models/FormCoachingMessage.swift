import Foundation

/// A coaching message triggered by a form checkpoint evaluation.
struct FormCoachingMessage: Sendable, Identifiable {
    let id = UUID()
    let checkpointName: String
    let message: String
    let priority: Priority

    enum Priority: Int, Comparable, Sendable {
        case caution = 0
        case warning = 1

        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}
