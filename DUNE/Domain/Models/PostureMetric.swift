import Foundation
import simd

// MARK: - Posture Metric Types

/// Types of posture measurements that can be assessed from body pose analysis.
enum PostureMetricType: String, Codable, CaseIterable, Sendable, Identifiable, Hashable {
    var id: String { rawValue }

    // Sagittal (side view) metrics
    case forwardHead            // Forward head posture (CVA proxy)
    case roundedShoulders       // Shoulder anterior displacement
    case thoracicKyphosis       // Upper back curvature
    case kneeHyperextension     // Knee recurvatum

    // Frontal (front view) metrics
    case shoulderAsymmetry      // Left/right shoulder height difference
    case hipAsymmetry           // Left/right hip height difference
    case kneeAlignment          // Valgus/varus (Q-angle)
    case lateralShift           // Trunk lateral displacement

    /// Whether this metric requires a side-view photo.
    var requiresSideView: Bool {
        switch self {
        case .forwardHead, .roundedShoulders, .thoracicKyphosis, .kneeHyperextension:
            return true
        case .shoulderAsymmetry, .hipAsymmetry, .kneeAlignment, .lateralShift:
            return false
        }
    }

    /// Score weight tier for overall posture score calculation.
    var scoreWeight: Double {
        switch self {
        // Tier 1 (60% total)
        case .forwardHead:          return 0.20
        case .roundedShoulders:     return 0.20
        case .shoulderAsymmetry:    return 0.20
        // Tier 2 (30% total)
        case .hipAsymmetry:         return 0.10
        case .kneeAlignment:        return 0.10
        case .lateralShift:         return 0.10
        // Tier 3 (10% total)
        case .thoracicKyphosis:     return 0.05
        case .kneeHyperextension:   return 0.05
        }
    }
}

// MARK: - Status

/// Assessment status for an individual posture metric.
enum PostureStatus: String, Codable, Sendable, Hashable, Comparable {
    case normal     // Within healthy range
    case caution    // Slightly outside normal
    case warning    // Significantly outside normal
    case unmeasurable // Could not be measured (low confidence, occluded)

    static func < (lhs: PostureStatus, rhs: PostureStatus) -> Bool {
        let order: [PostureStatus] = [.normal, .caution, .warning, .unmeasurable]
        guard let l = order.firstIndex(of: lhs),
              let r = order.firstIndex(of: rhs) else { return false }
        return l < r
    }
}

// MARK: - Metric Result

/// Result of measuring a single posture metric.
struct PostureMetricResult: Codable, Sendable, Hashable, Identifiable {
    var id: PostureMetricType { type }

    let type: PostureMetricType
    let value: Double           // Measured value (degrees or cm depending on metric)
    let unit: PostureMetricUnit
    let status: PostureStatus
    let score: Int              // 0-100 score for this individual metric

    /// Normalized score (0.0-1.0) for weighted composition.
    var normalizedScore: Double { Double(score) / 100.0 }
}

/// Unit of measurement for posture metrics.
enum PostureMetricUnit: String, Codable, Sendable, Hashable {
    case degrees    // Angular measurement
    case centimeters // Linear displacement
}

// MARK: - Capture Type

/// Which view angle a posture capture represents.
enum PostureCaptureType: String, Codable, Sendable, Hashable {
    case front  // Frontal (anterior) view
    case side   // Sagittal (lateral) view
}

// MARK: - Joint Position

/// Named 3D joint position extracted from Vision pose detection.
struct JointPosition3D: Codable, Sendable, Hashable, Identifiable {
    var id: String { name }
    let name: String            // Vision joint name (e.g. "centerHead")
    let x: Float                // Meters from root, right positive
    let y: Float                // Meters from root, up positive
    let z: Float                // Meters from root, toward camera positive

    var position: SIMD3<Float> {
        SIMD3(x, y, z)
    }

    init(name: String, position: SIMD3<Float>) {
        self.name = name
        self.x = position.x
        self.y = position.y
        self.z = position.z
    }

    init(name: String, x: Float, y: Float, z: Float) {
        self.name = name
        self.x = x
        self.y = y
        self.z = z
    }
}

// MARK: - Height Estimation

/// Whether body height was physically measured or used a reference value.
enum HeightEstimationType: String, Codable, Sendable, Hashable {
    case measured   // Accurate measurement from depth data
    case reference  // Default reference (1.8m)
}
