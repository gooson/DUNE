import SwiftUI

extension SleepStage.Stage {
    var color: Color {
        switch self {
        case .deep: .indigo
        case .core: .blue
        case .rem: .cyan
        case .awake: .orange
        }
    }
}
