import Foundation

enum Equipment: String, Codable, CaseIterable, Sendable {
    case barbell
    case dumbbell
    case machine
    case cable
    case bodyweight
    case band
    case kettlebell
    case other
}
