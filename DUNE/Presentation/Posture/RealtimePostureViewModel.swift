#if !os(visionOS)
import AVFoundation
import Foundation
import Observation

// MARK: - ViewModel

@Observable
@MainActor
final class RealtimePostureViewModel {

    // MARK: - State

    var isActive: Bool = false
    var currentAngles: [RealtimeAngle] = []
    var smoothedScore: Int = 0
    var skeletonKeypoints: [(String, CGPoint)] = []
    var guidanceState = GuidanceState()
    var is3DActive: Bool = false
    var cameraPosition: CameraPosition = .back

    // MARK: - Dependencies

    private let captureService = PostureCaptureService()
    private let tracker: RealtimePoseTracker

    var captureSession: AVCaptureSession { captureService.captureSession }

    // MARK: - Init

    init() {
        self.tracker = RealtimePoseTracker(captureService: captureService)
    }

    // MARK: - Lifecycle

    func start() {
        do {
            let position: AVCaptureDevice.Position = cameraPosition == .front ? .front : .back
            try captureService.setupCamera(position: position)

            // Setup guidance callbacks (same as capture mode)
            captureService.onFrameUpdate = { [weak self] state, _ in
                Task { @MainActor [weak self] in
                    self?.guidanceState = state
                }
            }

            captureService.startSession()

            // Start dual pipeline
            tracker.onStateUpdate = { [weak self] state in
                Task { @MainActor [weak self] in
                    self?.applyState(state)
                }
            }
            tracker.start()
            isActive = true
        } catch {
            AppLogger.data.error("[RealtimePostureViewModel] Camera setup failed: \(error.localizedDescription)")
            isActive = false
        }
    }

    func stop() {
        tracker.stop()
        captureService.onFrameUpdate = nil
        captureService.stopSession()
        isActive = false
    }

    func switchCamera() {
        stop()
        cameraPosition = cameraPosition == .front ? .back : .front
        start()
    }

    // MARK: - State Application

    private func applyState(_ state: RealtimePoseState) {
        currentAngles = state.currentAngles
        smoothedScore = state.smoothedScore
        skeletonKeypoints = state.skeletonKeypoints
        is3DActive = state.is3DActive
    }
}
#endif
