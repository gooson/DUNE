import SwiftUI

extension SleepStage.Stage {
    var label: String {
        switch self {
        case .awake: "Awake"
        case .core: "Core"
        case .deep: "Deep"
        case .rem: "REM"
        case .unspecified: "Asleep"
        }
    }

    var color: Color {
        switch self {
        case .deep: .indigo
        case .core: .blue
        case .rem: .cyan
        case .awake: .orange
        case .unspecified: Self.unspecifiedColor
        }
    }

    private static let unspecifiedColor = Color.blue.opacity(0.5)
}
