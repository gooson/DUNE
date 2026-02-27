import SwiftUI

/// Shared equipment icon mapping for Watch views.
/// Centralizes asset catalog path and SF Symbol fallback logic used by
/// EquipmentIconView (via ExerciseTileView and TemplateCardView).
///
/// WARNING: The rawValue strings here must match `Equipment.rawValue` from iOS Domain exactly.
/// These values are persisted in CloudKit via TemplateEntry and synced via WatchConnectivity.
/// Renaming an Equipment case requires a data migration strategy.
enum EquipmentIcon {

    /// Resolved icon type — pre-computed at init to avoid per-render switch dispatch.
    enum Resolved {
        case asset(String)   // Asset catalog path
        case symbol(String)  // SF Symbol name
    }

    /// Pre-resolves equipment rawValue to either an asset path or SF Symbol name.
    /// Call once at view init, not in body.
    static func resolve(for equipmentRawValue: String?) -> Resolved {
        if let eq = equipmentRawValue,
           let asset = assetName(for: eq) {
            return .asset(asset)
        }
        return .symbol(sfSymbol(for: equipmentRawValue))
    }

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
        case "chestPressMachine": kebab = "chest-press"
        case "shoulderPressMachine": kebab = "shoulder-press"
        case "legExtensionMachine": kebab = "leg-extension"
        case "legCurlMachine": kebab = "leg-curl"
        case "pecDeckMachine": kebab = "pec-deck"
        case "cableMachine": kebab = "cable-machine"
        case "machine": kebab = "machine"
        case "cable": kebab = "cable"
        case "bodyweight": kebab = "bodyweight"
        case "pullUpBar": kebab = "pull-up-bar"
        case "dipStation": kebab = "dip-station"
        case "band": kebab = "band"
        case "trx": kebab = "trx"
        case "medicineBall": kebab = "medicine-ball"
        case "stabilityBall": kebab = "stability-ball"
        case "other": kebab = "other"
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
        case "other":
            // Explicit handling — "other" is a valid Equipment case, not an unknown rawValue
            return "figure.strengthtraining.traditional"
        default:
            return "figure.strengthtraining.traditional"
        }
    }
}

// MARK: - EquipmentIconView

/// Reusable icon view that pre-resolves equipment mapping at init time.
/// Eliminates per-render switch dispatch in scrolling lists.
struct EquipmentIconView: View {
    let size: CGFloat
    private let resolved: EquipmentIcon.Resolved

    init(equipment: String?, size: CGFloat) {
        self.size = size
        self.resolved = EquipmentIcon.resolve(for: equipment)
    }

    var body: some View {
        switch resolved {
        case .asset(let name):
            Image(name)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(DS.Color.sandMuted)
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: size * 0.65))
                .foregroundStyle(DS.Color.sandMuted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
