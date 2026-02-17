import SwiftUI

extension Equipment {
    var displayName: String {
        switch self {
        case .barbell: "Barbell"
        case .dumbbell: "Dumbbell"
        case .machine: "Machine"
        case .cable: "Cable"
        case .bodyweight: "Bodyweight"
        case .band: "Band"
        case .kettlebell: "Kettlebell"
        case .other: "Other"
        }
    }

    var localizedDisplayName: String {
        switch self {
        case .barbell: "바벨"
        case .dumbbell: "덤벨"
        case .machine: "머신"
        case .cable: "케이블"
        case .bodyweight: "맨몸"
        case .band: "밴드"
        case .kettlebell: "케틀벨"
        case .other: "기타"
        }
    }

    var iconName: String {
        switch self {
        case .barbell: "dumbbell.fill"
        case .dumbbell: "dumbbell.fill"
        case .machine: "gearshape.fill"
        case .cable: "cable.connector"
        case .bodyweight: "figure.stand"
        case .band: "circle.dashed"
        case .kettlebell: "dumbbell.fill"
        case .other: "ellipsis.circle"
        }
    }
}
