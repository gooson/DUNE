import SwiftUI

extension Equipment {
    var displayName: String {
        switch self {
        case .barbell: String(localized: "Barbell")
        case .dumbbell: String(localized: "Dumbbell")
        case .kettlebell: String(localized: "Kettlebell")
        case .ezBar: String(localized: "EZ Bar")
        case .trapBar: String(localized: "Trap Bar")
        case .smithMachine: String(localized: "Smith Machine")
        case .legPressMachine: String(localized: "Leg Press Machine")
        case .hackSquatMachine: String(localized: "Hack Squat Machine")
        case .chestPressMachine: String(localized: "Chest Press Machine")
        case .shoulderPressMachine: String(localized: "Shoulder Press Machine")
        case .latPulldownMachine: String(localized: "Lat Pulldown Machine")
        case .legExtensionMachine: String(localized: "Leg Extension Machine")
        case .legCurlMachine: String(localized: "Leg Curl Machine")
        case .pecDeckMachine: String(localized: "Pec Deck Machine")
        case .cableMachine: String(localized: "Cable Machine")
        case .machine: String(localized: "Machine")
        case .cable: String(localized: "Cable")
        case .bodyweight: String(localized: "Bodyweight")
        case .pullUpBar: String(localized: "Pull-Up Bar")
        case .dipStation: String(localized: "Dip Station")
        case .band: String(localized: "Band")
        case .trx: String(localized: "TRX")
        case .medicineBall: String(localized: "Medicine Ball")
        case .stabilityBall: String(localized: "Stability Ball")
        case .other: String(localized: "Other")
        }
    }

    var equipmentDescription: String {
        switch self {
        case .barbell: String(localized: "Long bar with weight plates. Ideal for heavy lifting")
        case .dumbbell: String(localized: "Hand-held free weights. Effective for balanced development")
        case .kettlebell: String(localized: "Ball-shaped weight with handle. Great for dynamic exercises")
        case .ezBar: String(localized: "Curved bar that reduces wrist strain during curls")
        case .trapBar: String(localized: "Hexagonal frame bar. Ideal for deadlifts and shrugs")
        case .smithMachine: String(localized: "Barbell on vertical guide rails. Safe for heavy lifting")
        case .legPressMachine: String(localized: "Push weight with legs while seated. Lower body focus")
        case .hackSquatMachine: String(localized: "Back-supported squat machine. Targets quadriceps")
        case .chestPressMachine: String(localized: "Seated chest press machine. Isolates chest muscles")
        case .shoulderPressMachine: String(localized: "Seated shoulder press machine. Targets deltoids")
        case .latPulldownMachine: String(localized: "Pull-down cable machine. Develops lats")
        case .legExtensionMachine: String(localized: "Seated leg extension. Isolates quadriceps")
        case .legCurlMachine: String(localized: "Prone leg curl machine. Isolates hamstrings")
        case .pecDeckMachine: String(localized: "Seated fly machine. Develops inner chest")
        case .cableMachine: String(localized: "Pulley and cable system for multi-angle resistance")
        case .machine: String(localized: "Guided-track machine. Safe for beginners")
        case .cable: String(localized: "Pulley and cable for resistance from various angles")
        case .bodyweight: String(localized: "Exercises using only your body weight")
        case .pullUpBar: String(localized: "Bar for pull-up exercises. Targets back and biceps")
        case .dipStation: String(localized: "Support bars for dips. Targets chest and triceps")
        case .band: String(localized: "Elastic resistance band. Adjustable intensity, portable")
        case .trx: String(localized: "Suspension training system. Enhances core stability")
        case .medicineBall: String(localized: "Heavy ball for explosive full-body power exercises")
        case .stabilityBall: String(localized: "Exercise ball for balance and core training")
        case .other: String(localized: "Other exercise equipment")
        }
    }

    var iconName: String {
        switch self {
        case .barbell: "dumbbell.fill"
        case .dumbbell: "dumbbell.fill"
        case .kettlebell: "dumbbell.fill"
        case .ezBar: "dumbbell.fill"
        case .trapBar: "dumbbell.fill"
        case .smithMachine: "figure.strengthtraining.traditional"
        case .legPressMachine: "figure.strengthtraining.functional"
        case .hackSquatMachine: "figure.strengthtraining.functional"
        case .chestPressMachine: "gearshape.fill"
        case .shoulderPressMachine: "gearshape.fill"
        case .latPulldownMachine: "gearshape.fill"
        case .legExtensionMachine: "gearshape.fill"
        case .legCurlMachine: "gearshape.fill"
        case .pecDeckMachine: "gearshape.fill"
        case .cableMachine: "cable.connector"
        case .machine: "gearshape.fill"
        case .cable: "cable.connector"
        case .bodyweight: "figure.stand"
        case .pullUpBar: "figure.stand"
        case .dipStation: "figure.stand"
        case .band: "circle.dashed"
        case .trx: "figure.core.training"
        case .medicineBall: "circle.fill"
        case .stabilityBall: "circle.fill"
        case .other: "ellipsis.circle"
        }
    }

    /// Reusable template-rendered equipment icon at the given size.
    func svgIcon(size: CGFloat) -> some View {
        Image(svgAssetName)
            .resizable()
            .renderingMode(.template)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }

    var svgAssetName: String {
        switch self {
        case .barbell: "Equipment/equipment.barbell"
        case .dumbbell: "Equipment/equipment.dumbbell"
        case .kettlebell: "Equipment/equipment.kettlebell"
        case .ezBar: "Equipment/equipment.ez-bar"
        case .trapBar: "Equipment/equipment.trap-bar"
        case .smithMachine: "Equipment/equipment.smith-machine"
        case .legPressMachine: "Equipment/equipment.leg-press"
        case .hackSquatMachine: "Equipment/equipment.hack-squat"
        case .chestPressMachine: "Equipment/equipment.chest-press"
        case .shoulderPressMachine: "Equipment/equipment.shoulder-press"
        case .latPulldownMachine: "Equipment/equipment.lat-pulldown"
        case .legExtensionMachine: "Equipment/equipment.leg-extension"
        case .legCurlMachine: "Equipment/equipment.leg-curl"
        case .pecDeckMachine: "Equipment/equipment.pec-deck"
        case .cableMachine: "Equipment/equipment.cable-machine"
        case .machine: "Equipment/equipment.machine"
        case .cable: "Equipment/equipment.cable"
        case .bodyweight: "Equipment/equipment.bodyweight"
        case .pullUpBar: "Equipment/equipment.pull-up-bar"
        case .dipStation: "Equipment/equipment.dip-station"
        case .band: "Equipment/equipment.band"
        case .trx: "Equipment/equipment.trx"
        case .medicineBall: "Equipment/equipment.medicine-ball"
        case .stabilityBall: "Equipment/equipment.stability-ball"
        case .other: "Equipment/equipment.other"
        }
    }
}
