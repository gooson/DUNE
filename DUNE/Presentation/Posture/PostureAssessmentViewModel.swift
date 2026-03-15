#if !os(visionOS)
import AVFoundation
import AVFAudio
import Foundation
import Observation

// MARK: - Capture Phase

enum PostureCapturePhase: Sendable, Hashable {
    case idle
    case preparing
    case countdown(Int)
    case capturing
    case analyzing
    case result
    case error(String)
}

// MARK: - ViewModel

@Observable
@MainActor
final class PostureAssessmentViewModel {

    // MARK: - State

    var capturePhase: PostureCapturePhase = .idle
    var captureType: PostureCaptureType = .front

    var frontResult: PostureCaptureResult?
    var sideResult: PostureCaptureResult?

    var frontAssessment: PostureAssessment?
    var sideAssessment: PostureAssessment?

    var validationError: String?
    var isSaving = false

    var memo: String = ""

    // MARK: - Guidance State

    var guidanceState = GuidanceState()
    var cameraPosition: CameraPosition = .front
    var isAutoCapture: Bool = true

    /// Real-time 2D skeleton keypoints for preview overlay (normalized 0-1, origin bottom-left).
    var skeletonKeypoints: [(String, CGPoint)] = []

    // MARK: - Haptic Triggers

    private(set) var hapticCountdown: Int = 0
    private(set) var hapticSuccessCount: Int = 0
    private(set) var hapticErrorCount: Int = 0

    // MARK: - Computed

    private(set) var combinedAssessment = CombinedPostureAssessment(
        frontAssessment: nil, sideAssessment: nil, date: Date()
    )

    var canSave: Bool {
        frontAssessment != nil || sideAssessment != nil
    }

    var hasBothCaptures: Bool {
        frontAssessment != nil && sideAssessment != nil
    }

    var currentCaptureLabel: String {
        switch captureType {
        case .front: String(localized: "Front View")
        case .side: String(localized: "Side View")
        }
    }

    // MARK: - Tasks

    private var countdownTask: Task<Void, Never>?
    private var autoReadyStartTime: CFAbsoluteTime?
    private var isManualCountdown = false

    // MARK: - TTS

    private let speechSynthesizer = AVSpeechSynthesizer()
    private static let autoReadyDelay: TimeInterval = 2.0

    // MARK: - Dependencies

    private let captureService: PostureCaptureService
    private let analysisService = PostureAnalysisService()

    var captureSession: AVCaptureSession { captureService.captureSession }

    // MARK: - Init

    init(captureService: PostureCaptureService = PostureCaptureService()) {
        self.captureService = captureService
    }

    // MARK: - Camera Setup

    func setupCamera() {
        do {
            let position: AVCaptureDevice.Position = cameraPosition == .front ? .front : .back
            try captureService.setupCamera(position: position)
            setupGuidanceCallbacks()
            captureService.startSession()
            capturePhase = .preparing
        } catch {
            capturePhase = .error(String(localized: "Camera is not available"))
        }
    }

    func stopCamera() {
        countdownTask?.cancel()
        countdownTask = nil
        captureService.onFrameUpdate = nil
        captureService.stopSession()
    }

    // MARK: - Camera Switching

    func switchCamera() {
        countdownTask?.cancel()
        countdownTask = nil
        autoReadyStartTime = nil
        isManualCountdown = false
        guidanceState = GuidanceState()
        skeletonKeypoints = []

        do {
            try captureService.switchCamera()
            cameraPosition = captureService.currentPosition == .front ? .front : .back
            setupGuidanceCallbacks()
            capturePhase = .preparing
        } catch {
            capturePhase = .error(String(localized: "Camera is not available"))
        }
    }

    // MARK: - Guidance Callbacks

    private func setupGuidanceCallbacks() {
        captureService.onFrameUpdate = { [weak self] state, keypoints in
            Task { @MainActor [weak self] in
                self?.guidanceState = state
                self?.skeletonKeypoints = keypoints
                self?.handleAutoCapture(state)
            }
        }
    }

    private func handleAutoCapture(_ state: GuidanceState) {
        guard case .preparing = capturePhase else { return }
        guard isAutoCapture else { return }

        if state.isReady {
            let now = CFAbsoluteTimeGetCurrent()
            let start = autoReadyStartTime ?? now
            if autoReadyStartTime == nil { autoReadyStartTime = now }
            if now - start >= Self.autoReadyDelay {
                autoReadyStartTime = nil
                startCountdown(manual: false)
            }
        } else {
            autoReadyStartTime = nil
        }
    }

    // MARK: - Capture Flow

    func startCountdown(manual: Bool = true) {
        guard case .preparing = capturePhase else { return }
        countdownTask?.cancel()
        autoReadyStartTime = nil
        isManualCountdown = manual

        countdownTask = Task {
            do {
                for i in stride(from: 3, through: 1, by: -1) {
                    capturePhase = .countdown(i)
                    hapticCountdown = i

                    // TTS for back camera
                    if cameraPosition == .back {
                        speak("\(i)")
                    }

                    try await Task.sleep(for: .seconds(1))

                    // Auto-capture: cancel if pose is lost during countdown
                    // Manual capture: proceed regardless (user explicitly triggered)
                    if !isManualCountdown,
                       !guidanceState.isFullBodyVisible,
                       case .countdown = capturePhase {
                        capturePhase = .preparing
                        if cameraPosition == .back {
                            speak(String(localized: "Pose lost. Please hold still."))
                        }
                        return
                    }
                }
                guard !Task.isCancelled else { return }
                await performCapture()
            } catch {
                if case .countdown = capturePhase {
                    capturePhase = .preparing
                }
            }
        }
    }

    private func performCapture() async {
        capturePhase = .capturing

        do {
            let result = try await captureService.captureWithAveraging(frameCount: 3)
            capturePhase = .analyzing
            processResult(result)
        } catch let error as PostureCaptureError {
            capturePhase = .error(captureErrorMessage(error))
            hapticErrorCount += 1
        } catch {
            capturePhase = .error(String(localized: "An unexpected error occurred"))
            hapticErrorCount += 1
        }
    }

    private func processResult(_ result: PostureCaptureResult) {
        let metrics: [PostureMetricResult]

        switch captureType {
        case .front:
            metrics = analysisService.analyzeFrontView(joints: result.jointPositions)
            frontResult = result
            frontAssessment = PostureAssessment(
                captureType: .front,
                metrics: metrics,
                jointPositions: result.jointPositions,
                bodyHeight: result.bodyHeight,
                heightEstimation: result.heightEstimation,
                capturedAt: Date()
            )
        case .side:
            metrics = analysisService.analyzeSideView(joints: result.jointPositions)
            sideResult = result
            sideAssessment = PostureAssessment(
                captureType: .side,
                metrics: metrics,
                jointPositions: result.jointPositions,
                bodyHeight: result.bodyHeight,
                heightEstimation: result.heightEstimation,
                capturedAt: Date()
            )
        }

        combinedAssessment = CombinedPostureAssessment(
            frontAssessment: frontAssessment,
            sideAssessment: sideAssessment,
            date: Date()
        )
        capturePhase = .result
        hapticSuccessCount += 1

        if cameraPosition == .back {
            speak(String(localized: "Capture complete"))
        }
    }

    // MARK: - Navigation

    func proceedToSideCapture() {
        captureType = .side
        guidanceState = GuidanceState()
        skeletonKeypoints = []
        autoReadyStartTime = nil
        capturePhase = .preparing
    }

    func retakeCurrentCapture() {
        switch captureType {
        case .front:
            frontResult = nil
            frontAssessment = nil
        case .side:
            sideResult = nil
            sideAssessment = nil
        }
        combinedAssessment = CombinedPostureAssessment(
            frontAssessment: frontAssessment,
            sideAssessment: sideAssessment,
            date: Date()
        )
        guidanceState = GuidanceState()
        skeletonKeypoints = []
        autoReadyStartTime = nil
        capturePhase = .preparing
    }

    func resetAll() {
        countdownTask?.cancel()
        countdownTask = nil
        autoReadyStartTime = nil
        isManualCountdown = false
        captureType = .front
        frontResult = nil
        sideResult = nil
        frontAssessment = nil
        sideAssessment = nil
        memo = ""
        validationError = nil
        isSaving = false
        guidanceState = GuidanceState()
        skeletonKeypoints = []
        capturePhase = .idle
    }

    // MARK: - Record Creation

    func createValidatedRecord() -> PostureAssessmentRecord? {
        guard !isSaving else { return nil }
        isSaving = true

        guard frontAssessment != nil || sideAssessment != nil else {
            validationError = String(localized: "At least one capture is required")
            isSaving = false
            return nil
        }

        let overallScore = combinedAssessment.overallScore
        let trimmedMemo = String(memo.prefix(500))

        let record = PostureAssessmentRecord(
            date: Date(),
            overallScore: overallScore,
            frontMetrics: frontAssessment?.metrics ?? [],
            sideMetrics: sideAssessment?.metrics ?? [],
            frontJointPositions: frontAssessment?.jointPositions ?? [],
            sideJointPositions: sideAssessment?.jointPositions ?? [],
            frontImageData: frontResult?.imageData,
            sideImageData: sideResult?.imageData,
            bodyHeight: frontResult?.bodyHeight ?? sideResult?.bodyHeight,
            heightEstimation: frontResult?.heightEstimation ?? .reference,
            memo: trimmedMemo
        )

        return record
    }

    func didFinishSaving() {
        isSaving = false
    }

    // MARK: - TTS

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 1.0
        speechSynthesizer.speak(utterance)
    }

    // MARK: - Error Messages

    private func captureErrorMessage(_ error: PostureCaptureError) -> String {
        switch error {
        case .cameraUnavailable:
            String(localized: "Camera is not available")
        case .captureSessionNotRunning:
            String(localized: "Camera session is not active")
        case .photoCaptureFailed:
            String(localized: "Failed to capture photo")
        case .noPoseDetected:
            String(localized: "No body pose detected. Please ensure your full body is visible")
        case .insufficientConfidence:
            String(localized: "Could not detect body pose clearly. Please try again in better lighting")
        case .imageConversionFailed:
            String(localized: "Failed to process the captured image")
        }
    }
}
#endif
