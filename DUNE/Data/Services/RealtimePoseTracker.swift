#if !os(visionOS)
import AVFoundation
import Foundation
import os

/// Manages the dual pipeline (2D continuous + 3D periodic) for realtime posture analysis.
/// - 2D pipeline: Every frame callback → angle estimation via PostureAnalysisService
/// - 3D pipeline: Periodic sampling → full 3D pose detection + analysis
final class RealtimePoseTracker: @unchecked Sendable {

    /// A deep-copied pixel buffer can be transferred to the 3D detection task
    /// without sharing the camera pool's mutable storage.
    private struct SendablePixelBuffer: @unchecked Sendable {
        let value: CVPixelBuffer
    }

    // MARK: - Callbacks

    /// Called at throttled rate with updated state.
    var onStateUpdate: (@Sendable (RealtimePoseState) -> Void)?

    // MARK: - Dependencies

    private let captureService: PostureCaptureService
    private let analysisService = PostureAnalysisService()

    // MARK: - State (accessed on serialQueue only)

    private let serialQueue = DispatchQueue(label: "com.dune.posture.realtimeTracker")
    private var state = RealtimePoseState()
    private var scoreBuffer = ScoreRingBuffer(capacity: 10)
    private var is3DInFlight = false
    private var isStopped = true
    private var last3DSampleTime: CFAbsoluteTime = 0
    private var lastValidTime: CFAbsoluteTime = 0
    private var lastStateUpdateTime: CFAbsoluteTime = 0
    private var pending3DTask: Task<Void, Never>?

    // MARK: - Configuration

    /// Minimum interval between 3D samples (seconds). ~3-5fps.
    private static let min3DInterval: CFAbsoluteTime = 0.25 // 4fps target
    /// How long to keep last valid detection before clearing (seconds).
    private static let detectionTimeout: CFAbsoluteTime = 0.3
    /// Minimum interval between state update callbacks (seconds).
    private static let stateUpdateInterval: CFAbsoluteTime = 0.1 // 10fps max UI updates

    // MARK: - Init

    init(captureService: PostureCaptureService) {
        self.captureService = captureService
    }

    // MARK: - Lifecycle

    func start() {
        captureService.onRealtimeFrame = { [weak self] keypoints, sampleBuffer in
            self?.handleFrame(keypoints: keypoints, sampleBuffer: sampleBuffer)
        }

        serialQueue.async { [weak self] in
            self?.state = RealtimePoseState(isActive: true)
            self?.scoreBuffer.reset()
            self?.is3DInFlight = false
            self?.isStopped = false
            self?.lastStateUpdateTime = 0
        }
    }

    func stop() {
        captureService.onRealtimeFrame = nil
        pending3DTask?.cancel()
        serialQueue.async { [weak self] in
            self?.pending3DTask?.cancel()
            self?.pending3DTask = nil
            self?.isStopped = true
            self?.state = RealtimePoseState()
            self?.scoreBuffer.reset()
        }
    }

    // MARK: - Frame Handling

    private func handleFrame(keypoints: [(String, CGPoint)], sampleBuffer: CMSampleBuffer) {
        let now = CFAbsoluteTimeGetCurrent()
        var stateSnapshot: RealtimePoseState?
        var shouldSample3D = false

        // Keep all mutable tracker state on the serial queue, but do not carry
        // CMSampleBuffer itself across the async boundary.
        serialQueue.sync {
            guard self.state.isActive, !self.isStopped else { return }

            if keypoints.isEmpty {
                // No detection this frame
                self.state.framesSinceLastDetection += 1
                if now - self.lastValidTime > Self.detectionTimeout {
                    self.state.skeletonKeypoints = []
                    self.state.currentAngles = []
                }
            } else {
                // Valid detection
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
                    self.state.smoothedScore = self.scoreBuffer.average
                }
            }

            // 3D sampling trigger — copy pixel buffer on the capture queue so the
            // original CMSampleBuffer is never retained by a queued closure/task.
            if !self.is3DInFlight,
               !keypoints.isEmpty,
               now - self.last3DSampleTime >= Self.min3DInterval {
                self.is3DInFlight = true
                self.last3DSampleTime = now
                shouldSample3D = true
            }

            // Throttle UI updates
            if now - self.lastStateUpdateTime >= Self.stateUpdateInterval {
                self.lastStateUpdateTime = now
                stateSnapshot = self.state
            }
        }

        if shouldSample3D {
            if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
               let copiedBuffer = Self.copyPixelBuffer(pixelBuffer) {
                let copiedBufferBox = SendablePixelBuffer(value: copiedBuffer)
                serialQueue.sync {
                    guard self.state.isActive, !self.isStopped else {
                        self.is3DInFlight = false
                        return
                    }
                    self.pending3DTask = Task { [weak self, copiedBufferBox] in
                        await self?.perform3DDetection(copiedBufferBox.value)
                    }
                }
            } else {
                serialQueue.async { [weak self] in
                    self?.is3DInFlight = false
                }
            }
        }

        if let stateSnapshot {
            onStateUpdate?(stateSnapshot)
        }
    }

    // MARK: - 3D Detection

    private func perform3DDetection(_ pixelBuffer: CVPixelBuffer) async {
        guard !Task.isCancelled else { return }

        do {
            let result = try await captureService.detectPoseFromVideoFrame(pixelBuffer)

            guard !Task.isCancelled else { return }

            let metrics = analysisService.analyzeFrontView(joints: result.jointPositions)
                + analysisService.analyzeSideView(joints: result.jointPositions)
            let score = max(0, min(100, analysisService.calculateOverallScore(metrics: metrics)))

            serialQueue.async { [weak self] in
                guard let self, !self.isStopped else { return }
                self.state.is3DActive = true
                // 3D score is more accurate — replace the most recent 2D score
                self.scoreBuffer.replaceLast(score)
                self.state.smoothedScore = self.scoreBuffer.average
                self.is3DInFlight = false
                self.onStateUpdate?(self.state)
            }
        } catch {
            AppLogger.data.debug("[RealtimePoseTracker] 3D detection failed: \(error.localizedDescription)")
            serialQueue.async { [weak self] in
                self?.is3DInFlight = false
            }
        }
    }

    // MARK: - Pixel Buffer Copy

    /// Deep-copy a CVPixelBuffer so the original (owned by the camera pool) can
    /// be recycled immediately. Supports both planar (420YpCbCr) and interleaved formats.
    private static func copyPixelBuffer(_ source: CVPixelBuffer) -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(source)
        let height = CVPixelBufferGetHeight(source)
        let format = CVPixelBufferGetPixelFormatType(source)

        var copy: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, width, height, format,
            [kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary] as CFDictionary,
            &copy
        )
        guard status == kCVReturnSuccess, let dest = copy else { return nil }

        CVPixelBufferLockBaseAddress(source, .readOnly)
        CVPixelBufferLockBaseAddress(dest, [])
        defer {
            CVPixelBufferUnlockBaseAddress(source, .readOnly)
            CVPixelBufferUnlockBaseAddress(dest, [])
        }

        let planeCount = CVPixelBufferGetPlaneCount(source)
        if planeCount > 0 {
            for plane in 0..<planeCount {
                guard let srcAddr = CVPixelBufferGetBaseAddressOfPlane(source, plane),
                      let dstAddr = CVPixelBufferGetBaseAddressOfPlane(dest, plane) else { continue }
                let srcBPR = CVPixelBufferGetBytesPerRowOfPlane(source, plane)
                let dstBPR = CVPixelBufferGetBytesPerRowOfPlane(dest, plane)
                let planeHeight = CVPixelBufferGetHeightOfPlane(source, plane)
                if srcBPR == dstBPR {
                    memcpy(dstAddr, srcAddr, srcBPR * planeHeight)
                } else {
                    let copyBPR = min(srcBPR, dstBPR)
                    for row in 0..<planeHeight {
                        memcpy(dstAddr + row * dstBPR, srcAddr + row * srcBPR, copyBPR)
                    }
                }
            }
        } else {
            guard let srcAddr = CVPixelBufferGetBaseAddress(source),
                  let dstAddr = CVPixelBufferGetBaseAddress(dest) else { return nil }
            let srcBPR = CVPixelBufferGetBytesPerRow(source)
            let dstBPR = CVPixelBufferGetBytesPerRow(dest)
            if srcBPR == dstBPR {
                memcpy(dstAddr, srcAddr, srcBPR * height)
            } else {
                let copyBPR = min(srcBPR, dstBPR)
                for row in 0..<height {
                    memcpy(dstAddr + row * dstBPR, srcAddr + row * srcBPR, copyBPR)
                }
            }
        }

        return dest
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
