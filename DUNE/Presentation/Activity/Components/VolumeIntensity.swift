import SwiftUI

/// 5-level volume intensity based on weekly set count.
enum VolumeIntensity: Int, CaseIterable {
    case none = 0
    case light = 1
    case moderate = 2
    case high = 3
    case veryHigh = 4

    static func from(sets: Int) -> VolumeIntensity {
        switch sets {
        case 0:     .none
        case 1...5: .light
        case 6...10: .moderate
        case 11...15: .high
        default:     .veryHigh
        }
    }

    var label: String {
        switch self {
        case .none:     "0"
        case .light:    "1-5"
        case .moderate: "6-10"
        case .high:     "11-15"
        case .veryHigh: "16+"
        }
    }

    // Correction #83: static color cache for ForEach hot path
    private enum ColorCache {
        static let fill: [Color] = VolumeIntensity.allCases.map { level in
            switch level {
            case .none:     Color.secondary.opacity(0.08)
            case .light:    DS.Color.activity.opacity(0.2)
            case .moderate: DS.Color.activity.opacity(0.4)
            case .high:     DS.Color.activity.opacity(0.6)
            case .veryHigh: DS.Color.activity.opacity(0.8)
            }
        }
        static let stroke: [Color] = VolumeIntensity.allCases.map { level in
            level == .none
                ? Color.secondary.opacity(0.15)
                : fill[level.rawValue].opacity(0.6)
        }
    }

    var color: Color { ColorCache.fill[rawValue] }

    var strokeColor: Color { ColorCache.stroke[rawValue] }

    var description: String {
        switch self {
        case .none:     "이번 주 미훈련, 훈련 필요"
        case .light:    "가벼운 자극, 볼륨 추가 가능"
        case .moderate: "적정 볼륨, 유지 또는 소폭 증가"
        case .high:     "높은 볼륨, 회복 상태 확인 권장"
        case .veryHigh: "매우 높은 볼륨, 과훈련 주의"
        }
    }
}
