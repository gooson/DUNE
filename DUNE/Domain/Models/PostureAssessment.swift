import Foundation

/// Complete posture assessment result from a single capture session.
struct PostureAssessment: Sendable, Hashable {
    let captureType: PostureCaptureType
    let metrics: [PostureMetricResult]
    let jointPositions: [JointPosition3D]
    let bodyHeight: Double?             // Meters
    let heightEstimation: HeightEstimationType
    let capturedAt: Date

    /// Overall score for this capture (0-100), weighted by metric type.
    var overallScore: Int {
        let measurable = metrics.filter { $0.status != .unmeasurable }
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
        return Int(raw.rounded())
    }

    /// Worst status among all measurable metrics.
    var worstStatus: PostureStatus {
        metrics
            .filter { $0.status != .unmeasurable }
            .map(\.status)
            .max() ?? .normal
    }

    /// Metrics that need attention (caution or warning).
    var issueMetrics: [PostureMetricResult] {
        metrics.filter { $0.status == .caution || $0.status == .warning }
    }

    /// Count of successfully measured metrics.
    var measuredCount: Int {
        metrics.filter { $0.status != .unmeasurable }.count
    }
}

// MARK: - Combined Assessment

/// Combined front + side posture assessment for a complete evaluation.
struct CombinedPostureAssessment: Sendable, Hashable {
    let frontAssessment: PostureAssessment?
    let sideAssessment: PostureAssessment?
    let date: Date

    /// All metrics from both assessments combined.
    var allMetrics: [PostureMetricResult] {
        (frontAssessment?.metrics ?? []) + (sideAssessment?.metrics ?? [])
    }

    /// Overall combined score (0-100).
    var overallScore: Int {
        let measurable = allMetrics.filter { $0.status != .unmeasurable }
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
        return Int(raw.rounded())
    }

    /// Whether both front and side captures are complete.
    var isComplete: Bool {
        frontAssessment != nil && sideAssessment != nil
    }

    /// Body height from whichever assessment has it.
    var bodyHeight: Double? {
        sideAssessment?.bodyHeight ?? frontAssessment?.bodyHeight
    }
}
