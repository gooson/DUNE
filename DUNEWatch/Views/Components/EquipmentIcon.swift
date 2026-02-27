import Foundation

/// Shared equipment icon mapping for Watch views.
/// Centralizes asset catalog path and SF Symbol fallback logic used by
/// ExerciseTileView and TemplateCardView.
enum EquipmentIcon {

    /// Maps Equipment rawValue to Watch asset catalog path.
    /// Returns nil if the asset doesn't exist — callers should fall back to `sfSymbol(for:)`.
    static func assetName(for equipmentRawValue: String) -> String? {
        // Only specific, unambiguous equipment gets custom icons.
        // Generic categories (machine, cable, bodyweight, other) use SF Symbol fallback
        // because one icon can't represent all exercises in those categories.
        let kebab: String
        switch equipmentRawValue {
        case "barbell": kebab = "barbell"
        case "dumbbell": kebab = "dumbbell"
        case "kettlebell": kebab = "kettlebell"
        case "ezBar": kebab = "ez-bar"
        case "trapBar": kebab = "trap-bar"
        case "smithMachine": kebab = "smith-machine"
        case "legPressMachine": kebab = "leg-press"
        case "hackSquatMachine": kebab = "hack-squat"
        case "latPulldownMachine": kebab = "lat-pulldown"
        case "pecDeckMachine": kebab = "pec-deck"
        case "cableMachine": kebab = "cable-machine"
        case "pullUpBar": kebab = "pull-up-bar"
        case "dipStation": kebab = "dip-station"
        case "band": kebab = "band"
        case "trx": kebab = "trx"
        case "medicineBall": kebab = "medicine-ball"
        default: return nil
        }
        return "Equipment/equipment.\(kebab)"
    }

    /// SF Symbol name for equipment fallback when no custom asset exists.
    static func sfSymbol(for equipmentRawValue: String?) -> String {
        guard let eq = equipmentRawValue else { return "figure.strengthtraining.traditional" }
        switch eq {
        case "barbell", "dumbbell", "kettlebell", "ezBar", "trapBar":
            return "dumbbell.fill"
        case "bodyweight", "pullUpBar", "dipStation":
            return "figure.stand"
        case "cableMachine", "cable":
            return "cable.connector"
        case "chestPressMachine", "shoulderPressMachine", "legPressMachine",
             "hackSquatMachine", "legExtensionMachine", "legCurlMachine",
             "smithMachine", "machine":
            return "figure.strengthtraining.functional"
        case "band":
            return "circle.dashed"
        case "trx":
            return "figure.core.training"
        case "medicineBall", "stabilityBall":
            return "circle.fill"
        default:
            return "figure.strengthtraining.traditional"
        }
    }
}
