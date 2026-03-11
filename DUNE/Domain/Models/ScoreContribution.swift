import Foundation

struct ScoreContribution: Sendable, Identifiable, Hashable, Equatable, Codable {
    var id: String { factor.rawValue }
    let factor: Factor
    let impact: Impact
    let detail: String

    enum Factor: String, Sendable, CaseIterable, Codable {
        case hrv, rhr
    }

    enum Impact: String, Sendable, Codable {
        case positive, neutral, negative
    }
}
