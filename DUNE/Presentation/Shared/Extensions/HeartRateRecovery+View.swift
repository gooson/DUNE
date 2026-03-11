import SwiftUI

extension HeartRateRecovery.Rating {
    var color: Color {
        switch self {
        case .low: .red
        case .normal: .yellow
        case .good: .green
        }
    }
}
