import Foundation

struct ScoreContribution: Sendable, Identifiable, Hashable, Equatable {
    var id: String { factor.rawValue }
    let factor: Factor
    let impact: Impact
    let detail: String

    enum Factor: String, Sendable, CaseIterable {
        case hrv, rhr
    }

    enum Impact: String, Sendable {
        case positive, neutral, negative
    }
}
