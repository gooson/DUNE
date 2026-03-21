#if !os(visionOS)
import AVFoundation
import Foundation
import Observation
import UIKit

// MARK: - ViewModel

@Observable
@MainActor
final class RealtimePostureViewModel {

    // MARK: - State

    var isActive: Bool = false
    var currentAngles: [RealtimeAngle] = []
    var smoothedScore: Int = 0
    var skeletonKeypoints: [(String, CGPoint)] = []
    var skeletonImageSize: CGSize = .zero
    var guidanceState = GuidanceState()
    var is3DActive: Bool = false
    var cameraPosition: CameraPosition = .back
    var deviceOrientation: UIDeviceOrientation = .portrait

    // MARK: - Dependencies

    private let captureService = PostureCaptureService()
    private let tracker: RealtimePoseTracker

    var captureSession: AVCaptureSession { captureService.captureSession }
    var captureServiceDevice: AVCaptureDevice? { captureService.currentDevice }

    // MARK: - Init

    init() {
        self.tracker = RealtimePoseTracker(captureService: captureService)
    }

    // MARK: - Lifecycle

    func start() {
        do {
            let position: AVCaptureDevice.Position = cameraPosition == .front ? .front : .back
            // No photo capture needed — skip photoOutput to free GPU/buffer resources.
            // On front camera (TrueDepth), each output reserves hardware buffer slots
            // that compete with Vision's ML inference for shared resources.
            try captureService.setupCamera(position: position, needsPhotoCapture: false)
            captureService.updateDeviceOrientation(deviceOrientation)

            // Setup guidance callbacks (same as capture mode)
            captureService.onFrameUpdate = { [weak self] state, _, imageSize in
                Task { @MainActor [weak self] in
                    self?.guidanceState = state
                    self?.skeletonImageSize = imageSize
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

    func updateDeviceOrientation(_ orientation: UIDeviceOrientation) {
        guard orientation.isValidInterfaceOrientation else { return }
        deviceOrientation = orientation
        captureService.updateDeviceOrientation(orientation)
    }

    func updatePreviewRotationAngle(_ angle: CGFloat) {
        captureService.updatePreviewRotationAngle(angle)
    }

    // MARK: - State Application

    private func applyState(_ state: RealtimePoseState) {
        currentAngles = state.currentAngles
        smoothedScore = state.smoothedScore
        skeletonKeypoints = state.skeletonKeypoints
        is3DActive = state.is3DActive
    }
}

private extension UIDeviceOrientation {
    var isValidInterfaceOrientation: Bool {
        switch self {
        case .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight:
            return true
        default:
            return false
        }
    }
}
#endif
