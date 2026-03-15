import Foundation

// MARK: - Guidance State

/// Real-time guidance state from 2D pose detection during capture preview.
struct GuidanceState: Sendable, Hashable {
    var isFullBodyVisible: Bool = false
    var distanceStatus: DistanceStatus = .unknown
    var isStable: Bool = false
    var lightingStatus: LightingStatus = .unknown
    var isCorrectOrientation: Bool = false
    var areArmsRelaxed: Bool = false

    /// Whether all conditions are met for capture.
    var isReady: Bool {
        isFullBodyVisible
            && distanceStatus == .optimal
            && isStable
            && lightingStatus != .tooLow
            && isCorrectOrientation
            && areArmsRelaxed
    }

    /// User-facing hint for the most important unmet condition.
    var primaryHint: GuidanceHint? {
        if !isFullBodyVisible { return .fullBodyNotVisible }
        if distanceStatus == .tooClose { return .tooClose }
        if distanceStatus == .tooFar || distanceStatus == .slightlyFar { return .tooFar }
        if lightingStatus == .tooLow { return .lowLighting }
        if !isCorrectOrientation { return .wrongOrientation }
        if !areArmsRelaxed { return .armsNotRelaxed }
        if !isStable { return .notStable }
        return nil
    }

    /// Number of satisfied conditions (out of total checklist items).
    var satisfiedCount: Int {
        var count = 0
        if isFullBodyVisible { count += 1 }
        if distanceStatus == .optimal || distanceStatus == .slightlyFar { count += 1 }
        if isStable { count += 1 }
        if lightingStatus != .tooLow { count += 1 }
        return count
    }

    static let checklistTotal = 4
}

// MARK: - Distance Status

enum DistanceStatus: String, Sendable, Hashable {
    case unknown
    case tooFar
    case slightlyFar
    case optimal
    case tooClose
}

// MARK: - Lighting Status

enum LightingStatus: String, Sendable, Hashable {
    case unknown
    case tooLow
    case adequate
    case good
}

// MARK: - Camera Position

enum CameraPosition: String, Sendable, Hashable {
    case front
    case back
}

// MARK: - Guidance Hint

/// User-facing guidance hints for posture capture.
enum GuidanceHint: Sendable, Hashable {
    case fullBodyNotVisible
    case tooClose
    case tooFar
    case lowLighting
    case wrongOrientation
    case armsNotRelaxed
    case notStable

    var displayMessage: String {
        switch self {
        case .fullBodyNotVisible:
            String(localized: "Move back so your full body is visible")
        case .tooClose:
            String(localized: "Step back a little")
        case .tooFar:
            String(localized: "Move a little closer")
        case .lowLighting:
            String(localized: "Move to a brighter area")
        case .wrongOrientation:
            String(localized: "Face the camera directly")
        case .armsNotRelaxed:
            String(localized: "Relax your arms at your sides")
        case .notStable:
            String(localized: "Hold still for a moment")
        }
    }
}
