import SwiftUI

extension ConditionScore.Status {
    var color: Color {
        switch self {
        case .excellent: .green
        case .good: Color(red: 0.6, green: 0.8, blue: 0.2)
        case .fair: .yellow
        case .tired: .orange
        case .warning: .red
        }
    }
}
