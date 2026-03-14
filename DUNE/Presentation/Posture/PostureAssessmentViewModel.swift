import AVFoundation
import Foundation
import Observation

// MARK: - Capture Phase

enum PostureCapturePhase: Sendable, Hashable {
    case idle
    case guiding
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

    // MARK: - Computed

    var combinedAssessment: CombinedPostureAssessment {
        CombinedPostureAssessment(
            frontAssessment: frontAssessment,
            sideAssessment: sideAssessment,
            date: Date()
        )
    }

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
            try captureService.setupCamera()
            captureService.startSession()
            capturePhase = .guiding
        } catch {
            capturePhase = .error(String(localized: "Camera is not available"))
        }
    }

    func stopCamera() {
        captureService.stopSession()
    }

    // MARK: - Capture Flow

    func startCountdown() {
        guard case .guiding = capturePhase else { return }

        Task {
            for i in stride(from: 3, through: 1, by: -1) {
                capturePhase = .countdown(i)
                try await Task.sleep(for: .seconds(1))
            }
            await performCapture()
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
        } catch {
            capturePhase = .error(String(localized: "An unexpected error occurred"))
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

        capturePhase = .result
    }

    // MARK: - Navigation

    func proceedToSideCapture() {
        captureType = .side
        capturePhase = .guiding
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
        capturePhase = .guiding
    }

    func resetAll() {
        captureType = .front
        frontResult = nil
        sideResult = nil
        frontAssessment = nil
        sideAssessment = nil
        memo = ""
        validationError = nil
        isSaving = false
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
