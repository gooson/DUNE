import Foundation
import simd

/// Pure domain service that converts 3D joint positions into posture metrics.
/// No Vision/AVFoundation dependency — operates on raw coordinates only.
struct PostureAnalysisService: Sendable {

    // MARK: - Public API

    /// Analyze front-view joint positions.
    func analyzeFrontView(joints: [JointPosition3D]) -> [PostureMetricResult] {
        let lookup = Dictionary(joints.map { ($0.name, $0.position) }) { _, last in last }

        var results: [PostureMetricResult] = []
        results.append(measureShoulderAsymmetry(lookup))
        results.append(measureHipAsymmetry(lookup))
        results.append(measureKneeAlignment(lookup, side: "left"))
        results.append(measureKneeAlignment(lookup, side: "right"))
        results.append(measureLateralShift(lookup))

        // Merge left/right knee alignment into single worst result
        let kneeResults = results.filter { $0.type == .kneeAlignment }
        results.removeAll { $0.type == .kneeAlignment }
        if let worst = kneeResults.max(by: { $0.status < $1.status }) {
            results.append(worst)
        }

        return results
    }

    /// Analyze side-view joint positions.
    func analyzeSideView(joints: [JointPosition3D]) -> [PostureMetricResult] {
        let lookup = Dictionary(joints.map { ($0.name, $0.position) }) { _, last in last }

        var results: [PostureMetricResult] = []
        results.append(measureForwardHead(lookup))
        results.append(measureRoundedShoulders(lookup))
        results.append(measureThoracicKyphosis(lookup))
        results.append(measureKneeHyperextension(lookup))
        return results
    }

    /// Calculate overall posture score from all metrics.
    func calculateOverallScore(metrics: [PostureMetricResult]) -> Int {
        metrics.weightedOverallScore()
    }

    // MARK: - Frontal Metrics

    /// Measure shoulder height asymmetry (Y-coordinate difference).
    private func measureShoulderAsymmetry(_ joints: [String: SIMD3<Float>]) -> PostureMetricResult {
        guard let left = joints["leftShoulder"],
              let right = joints["rightShoulder"] else {
            return unmeasurable(.shoulderAsymmetry)
        }

        let diffCm = abs(left.y - right.y) * 100  // meters → cm
        guard diffCm.isFinite else { return unmeasurable(.shoulderAsymmetry) }

        let status = classifyAsymmetry(Double(diffCm))
        let score = scoreAsymmetry(Double(diffCm))

        return PostureMetricResult(
            type: .shoulderAsymmetry,
            value: Double(diffCm),
            unit: .centimeters,
            status: status,
            score: score
        )
    }

    /// Measure hip height asymmetry (Y-coordinate difference).
    private func measureHipAsymmetry(_ joints: [String: SIMD3<Float>]) -> PostureMetricResult {
        guard let left = joints["leftHip"],
              let right = joints["rightHip"] else {
            return unmeasurable(.hipAsymmetry)
        }

        let diffCm = abs(left.y - right.y) * 100
        guard diffCm.isFinite else { return unmeasurable(.hipAsymmetry) }

        let status = classifyAsymmetry(Double(diffCm))
        let score = scoreAsymmetry(Double(diffCm))

        return PostureMetricResult(
            type: .hipAsymmetry,
            value: Double(diffCm),
            unit: .centimeters,
            status: status,
            score: score
        )
    }

    /// Measure knee alignment (valgus/varus Q-angle) from frontal view.
    private func measureKneeAlignment(_ joints: [String: SIMD3<Float>], side: String) -> PostureMetricResult {
        let hipKey = side == "left" ? "leftHip" : "rightHip"
        let kneeKey = side == "left" ? "leftKnee" : "rightKnee"
        let ankleKey = side == "left" ? "leftAnkle" : "rightAnkle"

        guard let hip = joints[hipKey],
              let knee = joints[kneeKey],
              let ankle = joints[ankleKey] else {
            return unmeasurable(.kneeAlignment)
        }

        // Q-angle: angle at knee in frontal plane (X-Y only for frontal view)
        let hipXY = SIMD3<Float>(hip.x, hip.y, 0)
        let kneeXY = SIMD3<Float>(knee.x, knee.y, 0)
        let ankleXY = SIMD3<Float>(ankle.x, ankle.y, 0)

        let angle = angleBetweenPoints(a: hipXY, vertex: kneeXY, c: ankleXY)
        guard angle.isFinite else { return unmeasurable(.kneeAlignment) }

        // Normal Q-angle: 170-180° (nearly straight), <170° = valgus concern
        let deviation = max(0, 180.0 - Double(angle))
        let status: PostureStatus
        let score: Int

        if deviation <= 5 {
            status = .normal
            score = 100 - Int(deviation * 2)
        } else if deviation <= 12 {
            status = .caution
            score = max(50, 90 - Int(deviation * 3))
        } else {
            status = .warning
            score = max(20, 70 - Int(deviation * 3))
        }

        return PostureMetricResult(
            type: .kneeAlignment,
            value: deviation,
            unit: .degrees,
            status: status,
            score: max(0, min(100, score))
        )
    }

    /// Measure lateral trunk shift (head vs root X-offset).
    private func measureLateralShift(_ joints: [String: SIMD3<Float>]) -> PostureMetricResult {
        guard let head = joints["centerHead"],
              let root = joints["root"] else {
            return unmeasurable(.lateralShift)
        }

        let shiftCm = abs(head.x - root.x) * 100
        guard shiftCm.isFinite else { return unmeasurable(.lateralShift) }

        let status: PostureStatus
        let score: Int

        if shiftCm <= 1.0 {
            status = .normal
            score = 100 - Int(shiftCm * 10)
        } else if shiftCm <= 2.5 {
            status = .caution
            score = max(50, 90 - Int(shiftCm * 15))
        } else {
            status = .warning
            score = max(20, 70 - Int(shiftCm * 10))
        }

        return PostureMetricResult(
            type: .lateralShift,
            value: Double(shiftCm),
            unit: .centimeters,
            status: status,
            score: max(0, min(100, score))
        )
    }

    // MARK: - Sagittal Metrics

    /// Measure forward head posture (head anterior displacement from shoulder).
    private func measureForwardHead(_ joints: [String: SIMD3<Float>]) -> PostureMetricResult {
        guard let head = joints["centerHead"],
              let shoulder = joints["centerShoulder"] ?? midpoint(joints["leftShoulder"], joints["rightShoulder"]) else {
            return unmeasurable(.forwardHead)
        }

        // Z-axis: positive = toward camera. Forward head = head Z > shoulder Z
        let forwardCm = (head.z - shoulder.z) * 100
        guard forwardCm.isFinite else { return unmeasurable(.forwardHead) }

        let displacement = max(0, Double(forwardCm))  // Only measure forward displacement

        let status: PostureStatus
        let score: Int

        if displacement <= 2.5 {
            status = .normal
            score = 100 - Int(displacement * 8)
        } else if displacement <= 5.0 {
            status = .caution
            score = max(40, 80 - Int(displacement * 8))
        } else {
            status = .warning
            score = max(10, 60 - Int(displacement * 6))
        }

        return PostureMetricResult(
            type: .forwardHead,
            value: displacement,
            unit: .centimeters,
            status: status,
            score: max(0, min(100, score))
        )
    }

    /// Measure rounded shoulders (shoulder anterior displacement from spine).
    private func measureRoundedShoulders(_ joints: [String: SIMD3<Float>]) -> PostureMetricResult {
        guard let shoulder = joints["centerShoulder"] ?? midpoint(joints["leftShoulder"], joints["rightShoulder"]),
              let spine = joints["spine"] else {
            return unmeasurable(.roundedShoulders)
        }

        let forwardCm = (shoulder.z - spine.z) * 100
        guard forwardCm.isFinite else { return unmeasurable(.roundedShoulders) }

        let displacement = max(0, Double(forwardCm))

        let status: PostureStatus
        let score: Int

        if displacement <= 3.0 {
            status = .normal
            score = 100 - Int(displacement * 5)
        } else if displacement <= 6.0 {
            status = .caution
            score = max(40, 85 - Int(displacement * 7))
        } else {
            status = .warning
            score = max(10, 60 - Int(displacement * 5))
        }

        return PostureMetricResult(
            type: .roundedShoulders,
            value: displacement,
            unit: .centimeters,
            status: status,
            score: max(0, min(100, score))
        )
    }

    /// Measure thoracic kyphosis (upper back curvature angle).
    private func measureThoracicKyphosis(_ joints: [String: SIMD3<Float>]) -> PostureMetricResult {
        guard let shoulder = joints["centerShoulder"] ?? midpoint(joints["leftShoulder"], joints["rightShoulder"]),
              let spine = joints["spine"],
              let root = joints["root"] else {
            return unmeasurable(.thoracicKyphosis)
        }

        // Angle at spine point formed by shoulder-spine-root in sagittal plane (Y-Z)
        let shoulderYZ = SIMD3<Float>(0, shoulder.y, shoulder.z)
        let spineYZ = SIMD3<Float>(0, spine.y, spine.z)
        let rootYZ = SIMD3<Float>(0, root.y, root.z)

        let angle = angleBetweenPoints(a: shoulderYZ, vertex: spineYZ, c: rootYZ)
        guard angle.isFinite else { return unmeasurable(.thoracicKyphosis) }

        // Normal range: 150-175° (less = more curved)
        let degrees = Double(angle)

        let status: PostureStatus
        let score: Int

        if degrees >= 155 {
            status = .normal
            score = min(100, Int((degrees - 140) * 2.5))
        } else if degrees >= 140 {
            status = .caution
            score = max(40, Int((degrees - 120) * 2))
        } else {
            status = .warning
            score = max(10, Int(degrees / 2))
        }

        return PostureMetricResult(
            type: .thoracicKyphosis,
            value: 180.0 - degrees,  // Express as curvature deviation from straight
            unit: .degrees,
            status: status,
            score: max(0, min(100, score))
        )
    }

    /// Measure knee hyperextension from side view.
    private func measureKneeHyperextension(_ joints: [String: SIMD3<Float>]) -> PostureMetricResult {
        // Use whichever side has data (side view typically shows one side)
        let hipKey: String
        let kneeKey: String
        let ankleKey: String

        if joints["leftHip"] != nil {
            hipKey = "leftHip"; kneeKey = "leftKnee"; ankleKey = "leftAnkle"
        } else if joints["rightHip"] != nil {
            hipKey = "rightHip"; kneeKey = "rightKnee"; ankleKey = "rightAnkle"
        } else {
            return unmeasurable(.kneeHyperextension)
        }

        guard let hip = joints[hipKey],
              let knee = joints[kneeKey],
              let ankle = joints[ankleKey] else {
            return unmeasurable(.kneeHyperextension)
        }

        // Sagittal plane angle (Y-Z)
        let hipYZ = SIMD3<Float>(0, hip.y, hip.z)
        let kneeYZ = SIMD3<Float>(0, knee.y, knee.z)
        let ankleYZ = SIMD3<Float>(0, ankle.y, ankle.z)

        let angle = angleBetweenPoints(a: hipYZ, vertex: kneeYZ, c: ankleYZ)
        guard angle.isFinite else { return unmeasurable(.kneeHyperextension) }

        // Normal: 170-180°. >180° (hyperextension) shown as positive deviation
        let deviation = max(0, Double(angle) - 180.0)

        let status: PostureStatus
        let score: Int

        if deviation <= 3 {
            status = .normal
            score = 100 - Int(deviation * 5)
        } else if deviation <= 8 {
            status = .caution
            score = max(50, 85 - Int(deviation * 5))
        } else {
            status = .warning
            score = max(20, 60 - Int(deviation * 3))
        }

        return PostureMetricResult(
            type: .kneeHyperextension,
            value: deviation,
            unit: .degrees,
            status: status,
            score: max(0, min(100, score))
        )
    }

    // MARK: - Helpers

    /// Angle in degrees at vertex B formed by vectors BA and BC.
    private func angleBetweenPoints(a: SIMD3<Float>, vertex: SIMD3<Float>, c: SIMD3<Float>) -> Float {
        let ba = a - vertex
        let bc = c - vertex

        let dot = simd_dot(ba, bc)
        let magnitudes = simd_length(ba) * simd_length(bc)
        guard magnitudes > 0 else { return 0 }

        let cosAngle = simd_clamp(dot / magnitudes, -1.0, 1.0)
        return acos(cosAngle) * (180.0 / .pi)
    }

    /// Midpoint of two optional positions.
    private func midpoint(_ a: SIMD3<Float>?, _ b: SIMD3<Float>?) -> SIMD3<Float>? {
        guard let a, let b else { return a ?? b }
        return (a + b) / 2.0
    }

    /// Helper to create unmeasurable result.
    private func unmeasurable(_ type: PostureMetricType) -> PostureMetricResult {
        PostureMetricResult(type: type, value: 0, unit: .centimeters, status: .unmeasurable, score: 0)
    }

    /// Classify asymmetry (cm) into status.
    private func classifyAsymmetry(_ diffCm: Double) -> PostureStatus {
        if diffCm <= 1.0 { return .normal }
        if diffCm <= 2.5 { return .caution }
        return .warning
    }

    /// Score asymmetry (cm) into 0-100.
    private func scoreAsymmetry(_ diffCm: Double) -> Int {
        if diffCm <= 1.0 {
            return 100 - Int(diffCm * 10)
        } else if diffCm <= 2.5 {
            return max(50, 90 - Int(diffCm * 15))
        } else {
            return max(20, 70 - Int(diffCm * 10))
        }
    }
}
