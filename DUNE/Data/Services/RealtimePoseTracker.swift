#if !os(visionOS)
import AVFoundation
import Foundation
import os

/// Manages the dual pipeline (2D continuous + 3D periodic) for realtime posture analysis.
/// - 2D pipeline: Every frame callback → angle estimation via PostureAnalysisService
/// - 3D pipeline: Periodic sampling → full 3D pose detection + analysis
final class RealtimePoseTracker: @unchecked Sendable {

    // MARK: - Callbacks

    /// Called on every 2D frame with updated state.
    var onStateUpdate: (@Sendable (RealtimePoseState) -> Void)?

    // MARK: - Dependencies

    private let captureService: PostureCaptureService
    private let analysisService = PostureAnalysisService()

    // MARK: - State (accessed on serialQueue only)

    private let serialQueue = DispatchQueue(label: "com.dune.posture.realtimeTracker")
    private var state = RealtimePoseState()
    private var scoreBuffer = ScoreRingBuffer(capacity: 10)
    private var is3DInFlight = false
    private var last3DSampleTime: CFAbsoluteTime = 0
    private var lastValidKeypoints: [(String, CGPoint)] = []
    private var lastValidTime: CFAbsoluteTime = 0

    // MARK: - Configuration

    /// Minimum interval between 3D samples (seconds). ~3-5fps.
    private static let min3DInterval: CFAbsoluteTime = 0.25 // 4fps target
    /// How long to keep last valid detection before clearing (seconds).
    private static let detectionTimeout: CFAbsoluteTime = 0.3

    // MARK: - Init

    init(captureService: PostureCaptureService) {
        self.captureService = captureService
    }

    // MARK: - Lifecycle

    func start() {
        serialQueue.async { [weak self] in
            self?.state = RealtimePoseState(isActive: true)
            self?.scoreBuffer.reset()
            self?.is3DInFlight = false
        }

        captureService.onRealtimeFrame = { [weak self] keypoints, pixelBuffer in
            self?.handleFrame(keypoints: keypoints, pixelBuffer: pixelBuffer)
        }
    }

    func stop() {
        captureService.onRealtimeFrame = nil
        serialQueue.async { [weak self] in
            self?.state = RealtimePoseState()
            self?.scoreBuffer.reset()
        }
    }

    // MARK: - Frame Handling

    private func handleFrame(keypoints: [(String, CGPoint)], pixelBuffer: CVPixelBuffer) {
        serialQueue.async { [weak self] in
            guard let self, self.state.isActive else { return }

            let now = CFAbsoluteTimeGetCurrent()

            if keypoints.isEmpty {
                // No detection this frame
                self.state.framesSinceLastDetection += 1
                if now - self.lastValidTime > Self.detectionTimeout {
                    self.state.skeletonKeypoints = []
                    self.state.currentAngles = []
                }
            } else {
                // Valid detection
                self.lastValidKeypoints = keypoints
                self.lastValidTime = now
                self.state.framesSinceLastDetection = 0
                self.state.skeletonKeypoints = keypoints

                // 2D angle estimation
                let angles = self.analysisService.estimateAnglesFrom2D(keypoints: keypoints)
                self.state.currentAngles = angles

                // Update score from 2D angles (rough estimate)
                if !angles.isEmpty {
                    let avgAngleScore = self.score(from: angles)
                    self.scoreBuffer.append(avgAngleScore)
                    self.state.currentScore = avgAngleScore
                    self.state.smoothedScore = self.scoreBuffer.average
                }
            }

            // 3D sampling trigger
            if !self.is3DInFlight,
               !keypoints.isEmpty,
               now - self.last3DSampleTime >= Self.min3DInterval {
                self.is3DInFlight = true
                self.last3DSampleTime = now
                // pixelBuffer is retained by the Task closure automatically
                Task { [weak self] in
                    await self?.perform3DDetection(pixelBuffer)
                }
            }

            self.onStateUpdate?(self.state)
        }
    }

    // MARK: - 3D Detection

    private func perform3DDetection(_ pixelBuffer: CVPixelBuffer) async {
        do {
            let result = try await captureService.detectPoseFromVideoFrame(pixelBuffer)
            let metrics = analysisService.analyzeFrontView(joints: result.jointPositions)
                + analysisService.analyzeSideView(joints: result.jointPositions)
            let score = analysisService.calculateOverallScore(metrics: metrics)

            serialQueue.async { [weak self] in
                guard let self else { return }
                self.state.latestMetrics = metrics
                self.state.is3DActive = true
                // 3D score is more accurate — weight it more
                self.scoreBuffer.append(score)
                self.state.currentScore = score
                self.state.smoothedScore = self.scoreBuffer.average
                self.is3DInFlight = false
                self.onStateUpdate?(self.state)
            }
        } catch {
            AppLogger.data.debug("[RealtimePoseTracker] 3D detection failed: \(error.localizedDescription)")
            serialQueue.async { [weak self] in
                self?.is3DInFlight = false
                // Keep using 2D results — graceful degradation
            }
        }
    }

    // MARK: - Scoring

    /// Compute a rough score (0-100) from 2D angle estimations.
    private func score(from angles: [RealtimeAngle]) -> Int {
        guard !angles.isEmpty else { return 0 }

        var total = 0
        for angle in angles {
            switch angle.status {
            case .normal: total += 100
            case .caution: total += 60
            case .warning: total += 30
            case .unmeasurable: total += 0
            }
        }
        return total / angles.count
    }
}
#endif
