import SwiftUI

extension SleepStage.Stage {
    var label: String {
        switch self {
        case .awake: String(localized: "Awake")
        case .core: String(localized: "Core")
        case .deep: String(localized: "Deep")
        case .rem: "REM"
        case .unspecified: String(localized: "Asleep")
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
