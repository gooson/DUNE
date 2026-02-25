import Foundation

enum WeightUnit: String, CaseIterable, Sendable {
    case kg
    case lb

    var displayName: String {
        switch self {
        case .kg: "kg"
        case .lb: "lb"
        }
    }

    /// Convert from internal storage (always kg) to display unit
    func fromKg(_ kg: Double) -> Double {
        switch self {
        case .kg: kg
        case .lb: kg * 2.20462
        }
    }

    /// Convert from display unit to internal storage (always kg)
    func toKg(_ value: Double) -> Double {
        switch self {
        case .kg: value
        case .lb: value / 2.20462
        }
    }

}
