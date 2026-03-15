#if !os(visionOS)
import Foundation
@preconcurrency import Vision

/// Converts real-time 2D pose observations into GuidanceState for capture UI.
final class PostureGuidanceAnalyzer: @unchecked Sendable {

    // MARK: - Configuration

    /// Body ratio thresholds (head-ankle distance as fraction of image height).
    private static let bodyRatioTooFar: CGFloat = 0.35
    private static let bodyRatioSlightlyFar: CGFloat = 0.45
    private static let bodyRatioOptimalMax: CGFloat = 0.90
    // Above optimalMax → tooClose

    /// Luminance thresholds (0-1 scale).
    private static let luminanceTooLow: Double = 0.15
    private static let luminanceAdequate: Double = 0.25

    /// Stability: max allowed movement (normalized) over recent frames.
    private static let stabilityThreshold: CGFloat = 0.015
    private static let stabilityFrameCount = 5

    // MARK: - State

    private let lock = NSLock()
    private var recentNosePositions: [CGPoint] = []

    // MARK: - Analysis

    func analyze(
        observation: VNHumanBodyPoseObservation?,
        keypoints: [(String, CGPoint)],
        luminance: Double
    ) -> GuidanceState {
        let keypointMap = Dictionary(keypoints, uniquingKeysWith: { _, last in last })
        let lighting = lightingStatus(from: luminance)

        guard !keypointMap.isEmpty else {
            lock.withLock { recentNosePositions.removeAll() }
            return GuidanceState(lightingStatus: lighting)
        }

        let isFullBody = checkFullBodyVisible(keypointMap)
        let distance = checkDistance(keypointMap)
        let stable = checkStability(keypointMap)
        // checkOrientation requires the VNHumanBodyPoseObservation for confidence values
        let orientation = observation.map { checkOrientation($0) } ?? false
        let armsRelaxed = checkArmsRelaxed(keypointMap)

        return GuidanceState(
            isFullBodyVisible: isFullBody,
            distanceStatus: distance,
            isStable: stable,
            lightingStatus: lighting,
            isCorrectOrientation: orientation,
            areArmsRelaxed: armsRelaxed
        )
    }

    /// Reset stability tracking (e.g., when switching capture type).
    func reset() {
        lock.withLock { recentNosePositions.removeAll() }
    }

    // MARK: - Individual Checks

    /// Full body is visible when both ankles and head are detected.
    private func checkFullBodyVisible(_ keypoints: [String: CGPoint]) -> Bool {
        let hasHead = keypoints["nose"] != nil
        let hasLeftAnkle = keypoints["leftAnkle"] != nil
        let hasRightAnkle = keypoints["rightAnkle"] != nil
        return hasHead && (hasLeftAnkle || hasRightAnkle)
    }

    /// Distance based on head-to-ankle ratio in normalized image space.
    private func checkDistance(_ keypoints: [String: CGPoint]) -> DistanceStatus {
        guard let nose = keypoints["nose"] else { return .unknown }

        // Use the lowest ankle detected
        let ankleY: CGFloat
        if let left = keypoints["leftAnkle"], let right = keypoints["rightAnkle"] {
            ankleY = min(left.y, right.y)
        } else if let left = keypoints["leftAnkle"] {
            ankleY = left.y
        } else if let right = keypoints["rightAnkle"] {
            ankleY = right.y
        } else {
            return .unknown
        }

        // Vision normalized: origin bottom-left. nose.y > ankleY
        let bodyRatio = abs(nose.y - ankleY)

        if bodyRatio < Self.bodyRatioTooFar {
            return .tooFar
        } else if bodyRatio < Self.bodyRatioSlightlyFar {
            return .slightlyFar
        } else if bodyRatio <= Self.bodyRatioOptimalMax {
            return .optimal
        } else {
            return .tooClose
        }
    }

    /// Lighting status from average luminance.
    private func lightingStatus(from luminance: Double) -> LightingStatus {
        if luminance < Self.luminanceTooLow {
            return .tooLow
        } else if luminance < Self.luminanceAdequate {
            return .adequate
        } else {
            return .good
        }
    }

    /// Stability: nose position variance over recent frames.
    private func checkStability(_ keypoints: [String: CGPoint]) -> Bool {
        guard let nose = keypoints["nose"] else {
            lock.withLock { recentNosePositions.removeAll() }
            return false
        }

        return lock.withLock {
            recentNosePositions.append(nose)
            if recentNosePositions.count > Self.stabilityFrameCount {
                recentNosePositions.removeFirst(recentNosePositions.count - Self.stabilityFrameCount)
            }

            guard recentNosePositions.count >= Self.stabilityFrameCount else { return false }

            let xs = recentNosePositions.map(\.x)
            let ys = recentNosePositions.map(\.y)
            let xRange = (xs.max() ?? 0) - (xs.min() ?? 0)
            let yRange = (ys.max() ?? 0) - (ys.min() ?? 0)

            return xRange < Self.stabilityThreshold && yRange < Self.stabilityThreshold
        }
    }

    /// Basic orientation check: shoulders should be roughly level (not turned too far).
    /// For real-time guidance, we just check both shoulders are detected with reasonable confidence.
    private func checkOrientation(_ observation: VNHumanBodyPoseObservation) -> Bool {
        guard let leftShoulder = try? observation.recognizedPoint(.leftShoulder),
              let rightShoulder = try? observation.recognizedPoint(.rightShoulder),
              leftShoulder.confidence > 0.3,
              rightShoulder.confidence > 0.3 else {
            return false
        }
        return true
    }

    /// Arms relaxed: wrists should be near or below hip level.
    private func checkArmsRelaxed(_ keypoints: [String: CGPoint]) -> Bool {
        guard let leftHip = keypoints["leftHip"],
              let rightHip = keypoints["rightHip"] else {
            return true // Can't determine, assume OK
        }

        let hipY = (leftHip.y + rightHip.y) / 2.0
        let tolerance: CGFloat = 0.08

        // Check wrists are not raised significantly above hips
        // Vision coordinates: y increases upward
        if let leftWrist = keypoints["leftWrist"], leftWrist.y > hipY + tolerance {
            return false
        }
        if let rightWrist = keypoints["rightWrist"], rightWrist.y > hipY + tolerance {
            return false
        }

        return true
    }
}
#endif
