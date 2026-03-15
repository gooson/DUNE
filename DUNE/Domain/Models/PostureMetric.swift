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

    private static let statusOrder: [PostureStatus] = [.normal, .caution, .warning, .unmeasurable]

    static func < (lhs: PostureStatus, rhs: PostureStatus) -> Bool {
        guard let l = statusOrder.firstIndex(of: lhs),
              let r = statusOrder.firstIndex(of: rhs) else { return false }
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
    let confidence: Double      // 0.0-1.0 measurement confidence

    /// Normalized score (0.0-1.0) for weighted composition.
    var normalizedScore: Double { Double(score) / 100.0 }

    // Backward-compatible decoding for existing JSON without confidence field
    enum CodingKeys: String, CodingKey {
        case type, value, unit, status, score, confidence
    }

    init(type: PostureMetricType, value: Double, unit: PostureMetricUnit, status: PostureStatus, score: Int, confidence: Double = 1.0) {
        self.type = type
        self.value = value
        self.unit = unit
        self.status = status
        self.score = score
        self.confidence = max(0, min(1, confidence))
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(PostureMetricType.self, forKey: .type)
        value = try container.decode(Double.self, forKey: .value)
        unit = try container.decode(PostureMetricUnit.self, forKey: .unit)
        status = try container.decode(PostureStatus.self, forKey: .status)
        score = try container.decode(Int.self, forKey: .score)
        confidence = max(0, min(1, try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 1.0))
    }
}

extension [PostureMetricResult] {
    /// Weighted overall score (0-100) from measurable metrics, clamped.
    func weightedOverallScore() -> Int {
        let measurable = filter { $0.status != .unmeasurable }
        guard !measurable.isEmpty else { return 0 }

        var weightedSum = 0.0
        var totalWeight = 0.0

        for metric in measurable {
            let weight = metric.type.scoreWeight
            weightedSum += metric.normalizedScore * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else { return 0 }
        let raw = (weightedSum / totalWeight) * 100.0
        guard raw.isFinite else { return 0 }
        return Swift.max(0, Swift.min(100, Int(raw.rounded())))
    }
}

// MARK: - Body Part Mapping

extension PostureMetricType {
    /// Body parts affected by this posture metric, used for injury system integration.
    var affectedBodyParts: [BodyPart] {
        switch self {
        case .forwardHead:          return [.neck]
        case .roundedShoulders:     return [.shoulder]
        case .thoracicKyphosis:     return [.lowerBack]
        case .kneeHyperextension:   return [.knee]
        case .shoulderAsymmetry:    return [.shoulder]
        case .hipAsymmetry:         return [.hip]
        case .kneeAlignment:        return [.knee]
        case .lateralShift:         return [.hip]
        }
    }
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

    // 2D image-space coordinates (normalized 0-1), populated via VNHumanBodyPose3DObservation.pointInImage
    let imageX: CGFloat?
    let imageY: CGFloat?

    var position: SIMD3<Float> {
        SIMD3(x, y, z)
    }

    init(name: String, position: SIMD3<Float>, imageX: CGFloat? = nil, imageY: CGFloat? = nil) {
        self.name = name
        self.x = position.x
        self.y = position.y
        self.z = position.z
        self.imageX = imageX
        self.imageY = imageY
    }

    init(name: String, x: Float, y: Float, z: Float, imageX: CGFloat? = nil, imageY: CGFloat? = nil) {
        self.name = name
        self.x = x
        self.y = y
        self.z = z
        self.imageX = imageX
        self.imageY = imageY
    }
}

// MARK: - Height Estimation

/// Whether body height was physically measured or used a reference value.
enum HeightEstimationType: String, Codable, Sendable, Hashable {
    case measured   // Accurate measurement from depth data
    case reference  // Default reference (1.8m)
}
