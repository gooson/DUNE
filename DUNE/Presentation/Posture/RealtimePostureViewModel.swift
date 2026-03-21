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
    var cameraPosition: CameraPosition = .front
    var deviceOrientation: UIDeviceOrientation = .portrait

    // Form check mode
    var selectedExercise: ExerciseFormRule?
    var formState: ExerciseFormState?
    var showExercisePicker: Bool = false
    var isFormMode: Bool { selectedExercise != nil }

    // Voice coaching
    var isVoiceCoachingEnabled: Bool = false

    // MARK: - Dependencies

    private let captureService = PostureCaptureService()
    private let tracker: RealtimePoseTracker
    private let voiceCoach = FormVoiceCoach()

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
            try captureService.setupCamera(position: position)
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
        voiceCoach.stop()
        isVoiceCoachingEnabled = false
        captureService.onFrameUpdate = nil
        captureService.stopSession()
        isActive = false
    }

    func switchCamera() {
        tracker.stop()
        cameraPosition = cameraPosition == .front ? .back : .front
        do {
            try captureService.switchCamera()
            tracker.start()
        } catch {
            AppLogger.data.error("[RealtimePostureViewModel] Camera switch failed: \(error.localizedDescription)")
        }
    }

    func selectExercise(_ rule: ExerciseFormRule?) {
        selectedExercise = rule
        tracker.setExercise(rule)
        // Reset voice coaching on any exercise change (including switch between exercises)
        voiceCoach.setEnabled(false)
        isVoiceCoachingEnabled = false
    }

    func toggleVoiceCoaching() {
        isVoiceCoachingEnabled.toggle()
        voiceCoach.setEnabled(isVoiceCoachingEnabled)
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
        formState = state.formState

        // Feed form state to voice coach (guard isEnabled to avoid struct copy on every frame)
        if voiceCoach.isEnabled, let formState = state.formState, let rule = selectedExercise {
            voiceCoach.processFormState(formState, rule: rule)
        }
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
