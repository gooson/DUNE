#if !os(visionOS)
@preconcurrency import AVFoundation
import CoreImage
import CoreML
import Foundation
import ImageIO
import os
import UniformTypeIdentifiers
import UIKit
@preconcurrency import Vision

// MARK: - Protocol

protocol PostureCapturing: Sendable {
    func detectPose(from image: CGImage) async throws -> PostureCaptureResult
}

// MARK: - Capture Result

struct PostureCaptureResult: Sendable {
    let jointPositions: [JointPosition3D]
    let bodyHeight: Double?
    let heightEstimation: HeightEstimationType
    let imageData: Data?
}

// MARK: - Capture Error

enum PostureCaptureError: Error, Sendable {
    case cameraUnavailable
    case captureSessionNotRunning
    case photoCaptureFailed
    case noPoseDetected
    case insufficientConfidence
    case imageConversionFailed
}

enum PostureCaptureLiveSessionPresetOption: String, Sendable, CaseIterable {
    case automatic
    case hd1280x720
    case high
    case photo

    var displayLabel: String {
        switch self {
        case .automatic: "auto"
        case .hd1280x720: "720p"
        case .high: "high"
        case .photo: "photo"
        }
    }

    func resolvedPreset(for session: AVCaptureSession) -> AVCaptureSession.Preset {
        switch self {
        case .automatic:
            if session.canSetSessionPreset(.hd1280x720) {
                return .hd1280x720
            }
            if session.canSetSessionPreset(.high) {
                return .high
            }
            return .photo
        case .hd1280x720:
            return session.canSetSessionPreset(.hd1280x720) ? .hd1280x720 : Self.automatic.resolvedPreset(for: session)
        case .high:
            return session.canSetSessionPreset(.high) ? .high : Self.automatic.resolvedPreset(for: session)
        case .photo:
            return .photo
        }
    }

    static func fromLaunchArguments(_ arguments: [String]) -> Self {
        guard let rawValue = PostureCaptureLiveConfiguration.argumentValue(
            for: "--posture-live-preset",
            in: arguments
        )?.lowercased() else {
            return .automatic
        }

        switch rawValue {
        case "720p", "hd1280x720":
            return .hd1280x720
        case "high":
            return .high
        case "photo":
            return .photo
        default:
            return .automatic
        }
    }

    func next() -> Self {
        switch self {
        case .automatic: .hd1280x720
        case .hd1280x720: .high
        case .high: .photo
        case .photo: .automatic
        }
    }
}

enum PostureCaptureLivePixelFormatOption: String, Sendable, CaseIterable {
    case automatic
    case fullRange420f
    case videoRange420v
    case bgra

    var displayLabel: String {
        switch self {
        case .automatic: "auto"
        case .fullRange420f: "420f"
        case .videoRange420v: "420v"
        case .bgra: "32BGRA"
        }
    }

    func resolvedFormat(from availableFormats: [OSType]) -> OSType? {
        switch self {
        case .automatic:
            return Self.preferredNativeFormat(from: availableFormats)
        case .fullRange420f:
            if availableFormats.contains(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
                return kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            }
            return Self.preferredNativeFormat(from: availableFormats)
        case .videoRange420v:
            if availableFormats.contains(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
                return kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
            }
            return Self.preferredNativeFormat(from: availableFormats)
        case .bgra:
            if availableFormats.contains(kCVPixelFormatType_32BGRA) {
                return kCVPixelFormatType_32BGRA
            }
            return Self.preferredNativeFormat(from: availableFormats)
        }
    }

    static func fromLaunchArguments(_ arguments: [String]) -> Self {
        guard let rawValue = PostureCaptureLiveConfiguration.argumentValue(
            for: "--posture-live-format",
            in: arguments
        )?.lowercased() else {
            return .automatic
        }

        switch rawValue {
        case "420f", "fullrange", "full-range":
            return .fullRange420f
        case "420v", "videorange", "video-range":
            return .videoRange420v
        case "bgra", "32bgra":
            return .bgra
        default:
            return .automatic
        }
    }

    func next() -> Self {
        switch self {
        case .automatic: .fullRange420f
        case .fullRange420f: .videoRange420v
        case .videoRange420v: .bgra
        case .bgra: .automatic
        }
    }

    static func preferredNativeFormat(from availableFormats: [OSType]) -> OSType? {
        if availableFormats.contains(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
            return kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        }
        if availableFormats.contains(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
            return kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        }
        if availableFormats.contains(kCVPixelFormatType_32BGRA) {
            return kCVPixelFormatType_32BGRA
        }
        return availableFormats.first
    }
}

struct PostureCaptureLiveConfiguration: Sendable, Equatable {
    var preset: PostureCaptureLiveSessionPresetOption = .automatic
    var pixelFormat: PostureCaptureLivePixelFormatOption = .automatic

    static func current(arguments: [String] = ProcessInfo.processInfo.arguments) -> Self {
        Self(
            preset: PostureCaptureLiveSessionPresetOption.fromLaunchArguments(arguments),
            pixelFormat: PostureCaptureLivePixelFormatOption.fromLaunchArguments(arguments)
        )
    }

    static func argumentValue(for key: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: key), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    func cyclingPreset() -> Self {
        var copy = self
        copy.preset = preset.next()
        return copy
    }

    func cyclingPixelFormat() -> Self {
        var copy = self
        copy.pixelFormat = pixelFormat.next()
        return copy
    }
}

struct PostureCaptureDiagnostics: Sendable, Equatable {
    var configuredPreset: String = ""
    var configuredPixelFormat: String = ""
    var sessionPreset: String = ""
    var frameWidth: Int = 0
    var frameHeight: Int = 0
    var pixelFormat: String = ""
    var lastPoseLatencyMs: Int = 0
    var poseErrorCount: Int = 0
    var lastVisionError: String?
}

// MARK: - PostureCaptureService

final class PostureCaptureService: NSObject, PostureCapturing, @unchecked Sendable {

    // MARK: - Camera Session

    let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let videoDataQueue = DispatchQueue(label: "com.dune.posture.videoData", qos: .userInitiated)
    private let sessionQueue = DispatchQueue(label: "com.dune.posture.session", qos: .userInitiated)
    private let continuationLock = NSLock()
    private let orientationLock = NSLock()
    private var photoContinuation: CheckedContinuation<(CGImage, Data?), any Error>?
    private var currentDeviceOrientation: UIDeviceOrientation = .portrait
    private var currentPreviewRotationAngle: CGFloat?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?

    // MARK: - Real-time Guidance

    private let guidanceAnalyzer = PostureGuidanceAnalyzer()
    private let bodyPoseRequest = VNDetectHumanBodyPoseRequest()
    /// Serializes ALL Vision perform() calls across 2D and 3D pipelines.
    /// Vision's internal ML buffer pool is shared — concurrent perform() calls
    /// cause "Could not create mlImage buffer" errors from pool exhaustion.
    private let visionSemaphore = DispatchSemaphore(value: 1)
    // Accessed only on videoDataQueue (single serial queue) — no lock needed.
    private var lastFrameAnalysisTime: CFAbsoluteTime = 0
    private var last3DSamplingTime: CFAbsoluteTime = 0
    private static let frameAnalysisInterval: CFAbsoluteTime = 0.1 // 10fps max
    /// 3D sampling interval — controls how often a CGImage is passed to onRealtimeFrame.
    private static let threeDSamplingInterval: CFAbsoluteTime = 0.25 // ~4fps
    /// Combined frame update callback: guidance state + skeleton keypoints in a single dispatch.
    var onFrameUpdate: (@Sendable (GuidanceState, [(String, CGPoint)], CGSize) -> Void)?
    /// Realtime analysis callback: keypoints + CGImage for 3D sampling.
    /// CGImage is created from the pool buffer via CPU memcpy — completely independent of
    /// the camera pool, so pool buffers are recycled immediately in captureOutput.
    var onRealtimeFrame: (@Sendable ([(String, CGPoint)], CGImage?) -> Void)?
    var onDiagnosticsUpdate: (@Sendable (PostureCaptureDiagnostics) -> Void)?
    private var livePoseErrorCount = 0
    private var liveConfiguration = PostureCaptureLiveConfiguration.current()

    // MARK: - Camera State

    private(set) var currentPosition: AVCaptureDevice.Position = .front
    private(set) var currentDevice: AVCaptureDevice?
    private var isPhotoOutputEnabled = true

    // MARK: - Configuration

    // Final captures use a stricter threshold than live guidance so weak
    // outliers do not leak into the saved overlay or posture analysis.
    static let capturedJointMinimumConfidence: Float = 0.5
    private static let previewJointMinimumConfidence: Float = 0.3
    private static let jpegCompressionQuality: CGFloat = 0.7
    private static let referenceBodyHeight: Double = 1.8

    static var isDiagnosticsEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("--posture-capture-diagnostics")
    }

    static var shouldAutoOpenCaptureOnLaunch: Bool {
        ProcessInfo.processInfo.arguments.contains("--posture-open-capture")
    }

    var currentLiveConfiguration: PostureCaptureLiveConfiguration {
        liveConfiguration
    }

    // MARK: - Setup

    /// - Parameter needsPhotoCapture: When false, photoOutput is NOT added to the session.
    ///   This frees GPU/buffer resources on front camera (TrueDepth) where the depth sensor
    ///   hardware competes with Vision's ML buffer allocation. Each AVCaptureOutput added
    ///   to the session reserves hardware buffer slots — fewer outputs = more headroom.
    func setupCamera(position: AVCaptureDevice.Position = .front, needsPhotoCapture: Bool = true) throws {
        isPhotoOutputEnabled = needsPhotoCapture

        // Drain any leaked photoContinuation from a previous session
        continuationLock.withLock {
            photoContinuation?.resume(throwing: PostureCaptureError.captureSessionNotRunning)
            photoContinuation = nil
        }

        currentPosition = position
        configureLiveBodyPoseCompute(for: position)

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: position
        ) else {
            throw PostureCaptureError.cameraUnavailable
        }
        currentDevice = device
        rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)

        let input = try AVCaptureDeviceInput(device: device)

        captureSession.beginConfiguration()

        // Remove existing inputs/outputs for camera switching
        for existing in captureSession.inputs {
            captureSession.removeInput(existing)
        }
        for existing in captureSession.outputs {
            captureSession.removeOutput(existing)
        }

        guard captureSession.canAddInput(input) else {
            captureSession.commitConfiguration()
            throw PostureCaptureError.cameraUnavailable
        }
        captureSession.addInput(input)
        captureSession.sessionPreset = liveConfiguration.preset.resolvedPreset(for: captureSession)

        // Only add photoOutput when photo capture is needed (e.g. PostureAssessmentViewModel).
        // Each output reserves hardware buffer slots. On front camera (TrueDepth), the depth
        // sensor already consumes shared GPU resources. Omitting photoOutput in realtime-only
        // mode frees buffer slots so Vision's ML inference can allocate its internal buffers.
        if needsPhotoCapture {
            guard captureSession.canAddOutput(photoOutput) else {
                captureSession.commitConfiguration()
                throw PostureCaptureError.cameraUnavailable
            }
            captureSession.addOutput(photoOutput)
            // Front camera (TrueDepth): use .speed to minimize GPU resource pre-allocation.
            // The depth sensor hardware already consumes shared buffer slots — .quality
            // pre-allocates additional high-res buffers that starve Vision's ML inference.
            photoOutput.maxPhotoQualityPrioritization = position == .front ? .speed : .quality
        }

        // Add video data output for real-time pose guidance
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
            applyLiveVideoOutputConfiguration()
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataQueue)
            if let connection = videoDataOutput.connection(with: .video) {
                // Keep raw video-data buffers in native sensor orientation and let
                // Vision apply explicit orientation metadata per frame.
                connection.videoRotationAngle = 0
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
        }

        captureSession.commitConfiguration()
        publishDiagnostics(
            frameWidth: 0,
            frameHeight: 0,
            pixelFormat: liveConfiguration.pixelFormat.displayLabel,
            lastPoseLatencyMs: 0,
            lastVisionError: nil
        )
    }

    func switchCamera() throws {
        let newPosition: AVCaptureDevice.Position = currentPosition == .front ? .back : .front
        try setupCamera(position: newPosition, needsPhotoCapture: isPhotoOutputEnabled)
    }

    func updateLiveConfiguration(_ configuration: PostureCaptureLiveConfiguration) throws {
        let previousConfiguration = liveConfiguration
        liveConfiguration = configuration
        do {
            try setupCamera(position: currentPosition, needsPhotoCapture: isPhotoOutputEnabled)
            // Always restart — startSession() guards against double-start on sessionQueue,
            // avoiding the TOCTOU race of reading isRunning on the caller thread.
            startSession()
        } catch {
            liveConfiguration = previousConfiguration
            throw error
        }
    }

    func startSession() {
        sessionQueue.async { [captureSession] in
            guard !captureSession.isRunning else { return }
            captureSession.startRunning()
        }
    }

    func stopSession() {
        sessionQueue.async { [captureSession] in
            guard captureSession.isRunning else { return }
            captureSession.stopRunning()
        }
    }

    /// CPU compute device, resolved lazily to avoid crash during static init in simulators.
    private lazy var cpuDevice: MLComputeDevice? = {
        MLComputeDevice.allComputeDevices.first { if case .cpu = $0 { return true }; return false }
    }()

    /// Force CPU compute for the stored bodyPoseRequest on front camera.
    /// On some devices (iPad, TrueDepth iPhones), the front camera competes
    /// with Vision's Neural Engine for shared resources. CPU inference
    /// is ~10-15ms per frame — well within the 10fps (100ms) budget.
    private func configureLiveBodyPoseCompute(for position: AVCaptureDevice.Position) {
        bodyPoseRequest.setComputeDevice(
            position == .front ? cpuDevice : nil,
            for: .main
        )
    }

    /// Configure per-call Vision requests for the current camera position.
    private func configureRequestCompute(_ requests: [VNRequest]) {
        guard currentPosition == .front, let cpu = cpuDevice else { return }
        for request in requests {
            request.setComputeDevice(cpu, for: .main)
        }
    }

    func updateDeviceOrientation(_ orientation: UIDeviceOrientation) {
        guard Self.isInterfaceOrientation(orientation) else { return }
        orientationLock.withLock {
            currentDeviceOrientation = orientation
        }
    }

    func updatePreviewRotationAngle(_ angle: CGFloat) {
        guard angle.isFinite else { return }
        orientationLock.withLock {
            currentPreviewRotationAngle = Self.normalizedRightAngle(from: angle)
        }
    }

    // MARK: - Photo Capture

    func capturePhoto() async throws -> (CGImage, Data?) {
        guard captureSession.isRunning else {
            throw PostureCaptureError.captureSessionNotRunning
        }

        let alreadyCapturing = continuationLock.withLock { photoContinuation != nil }
        guard !alreadyCapturing else {
            throw PostureCaptureError.photoCaptureFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuationLock.withLock { self.photoContinuation = continuation }
            self.configurePhotoConnectionForCurrentOrientation()
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    // MARK: - Pose Detection

    func detectPose(from image: CGImage) async throws -> PostureCaptureResult {
        try await detectPose(from: image, orientedJPEG: nil)
    }

    func detectPose(from image: CGImage, orientedJPEG: Data?) async throws -> PostureCaptureResult {
        let request3D = VNDetectHumanBodyPose3DRequest()
        let request2D = VNDetectHumanBodyPoseRequest()
        configureRequestCompute([request3D, request2D])

        // Pass EXIF orientation so pointInImage() returns coordinates in the
        // displayed (portrait, mirrored-for-front-camera) coordinate space,
        // not in the raw landscape sensor coordinate space.
        let orientation = Self.extractOrientation(from: orientedJPEG)
        let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            DispatchQueue.global(qos: .userInitiated).async { [visionSemaphore] in
                visionSemaphore.wait()
                do {
                    try handler.perform([request3D, request2D])
                    visionSemaphore.signal()
                    continuation.resume()
                } catch {
                    visionSemaphore.signal()
                    continuation.resume(throwing: error)
                }
            }
        }

        // --- Try 3D results first ---
        if let observation3D = request3D.results?.first {
            let confidenceMap = Self.captureConfidenceBy2DJointName(from: request2D.results?.first)
            let joints = extractJointPositions(from: observation3D, confidenceBy2DJointName: confidenceMap)

            if !joints.isEmpty {
                let bodyHeight: Double?
                let heightEstimation: HeightEstimationType
                let height = observation3D.bodyHeight
                if height.isFinite, height > 0.5, height < 2.5 {
                    bodyHeight = Double(height)
                    heightEstimation = .measured
                } else {
                    bodyHeight = Self.referenceBodyHeight
                    heightEstimation = .reference
                }

                let imageData: Data? = if let orientedJPEG {
                    compressOrientedData(orientedJPEG)
                } else {
                    compressImage(image)
                }

                return PostureCaptureResult(
                    jointPositions: joints,
                    bodyHeight: bodyHeight,
                    heightEstimation: heightEstimation,
                    imageData: imageData
                )
            }
        }

        // --- Fallback: 2D-only results ---
        // 3D detection fails on some devices/cameras (iPad front camera,
        // "ABPKPersonIDTracker not supported", "mlImage buffer" errors).
        // 2D joints with z=0 still provide frontal metrics (shoulder/hip
        // asymmetry, knee alignment, lateral shift). Sagittal metrics
        // (forward head, rounded shoulders) return "unmeasurable".
        guard let observation2D = request2D.results?.first else {
            throw PostureCaptureError.noPoseDetected
        }

        let joints2D = Self.extractJointPositionsFrom2D(observation2D)
        guard !joints2D.isEmpty else {
            throw PostureCaptureError.insufficientConfidence
        }

        let imageData: Data? = if let orientedJPEG {
            compressOrientedData(orientedJPEG)
        } else {
            compressImage(image)
        }

        return PostureCaptureResult(
            jointPositions: joints2D,
            bodyHeight: Self.referenceBodyHeight,
            heightEstimation: .reference,
            imageData: imageData
        )
    }

    // MARK: - 3D Pose Detection from Video Frame

    /// Detect 3D pose from a CGImage extracted from a video frame.
    /// CGImage has zero dependency on the AVCaptureSession buffer pool,
    /// so this can safely run on any queue/Task without causing pool starvation.
    func detectPoseFromVideoFrame(_ cgImage: CGImage) async throws -> PostureCaptureResult {
        try await detectPose(from: cgImage, orientedJPEG: nil)
    }

    // MARK: - Full Capture Pipeline

    func captureAndDetect() async throws -> PostureCaptureResult {
        let (cgImage, orientedJPEG) = try await capturePhoto()
        return try await detectPose(from: cgImage, orientedJPEG: orientedJPEG)
    }

    // MARK: - Multi-Frame Averaging

    func captureWithAveraging(frameCount: Int = 3) async throws -> PostureCaptureResult {
        var allResults: [PostureCaptureResult] = []

        for _ in 0..<frameCount {
            let result = try await captureAndDetect()
            allResults.append(result)
            try await Task.sleep(for: .milliseconds(300))
        }

        return averageResults(allResults)
    }

    // MARK: - Joint Extraction

    private static let trackedJoints: [(VNHumanBodyPose3DObservation.JointName, String)] = [
        (.centerHead, "centerHead"),
        (.topHead, "topHead"),
        (.leftShoulder, "leftShoulder"),
        (.rightShoulder, "rightShoulder"),
        (.centerShoulder, "centerShoulder"),
        (.spine, "spine"),
        (.root, "root"),
        (.leftHip, "leftHip"),
        (.rightHip, "rightHip"),
        (.leftElbow, "leftElbow"),
        (.rightElbow, "rightElbow"),
        (.leftWrist, "leftWrist"),
        (.rightWrist, "rightWrist"),
        (.leftKnee, "leftKnee"),
        (.rightKnee, "rightKnee"),
        (.leftAnkle, "leftAnkle"),
        (.rightAnkle, "rightAnkle"),
    ]

    private static let confidenceSourceJoints: [VNHumanBodyPoseObservation.JointName] = [
        .nose,
        .neck,
        .root,
        .leftShoulder,
        .rightShoulder,
        .leftElbow,
        .rightElbow,
        .leftWrist,
        .rightWrist,
        .leftHip,
        .rightHip,
        .leftKnee,
        .rightKnee,
        .leftAnkle,
        .rightAnkle,
    ]

    private func extractJointPositions(
        from observation: VNHumanBodyPose3DObservation,
        confidenceBy2DJointName: [VNHumanBodyPoseObservation.JointName: Float]
    ) -> [JointPosition3D] {
        var positions: [JointPosition3D] = []

        for (jointName, name) in Self.trackedJoints {
            guard let point = try? observation.recognizedPoint(jointName) else {
                continue
            }

            // localPosition is simd_float4x4 — translation in columns.3
            let translation = point.localPosition.columns.3
            let x = translation.x
            let y = translation.y
            let z = translation.z

            guard Self.shouldKeepCapturedJoint(
                confidence: Self.capturedJointConfidence(
                    for: name,
                    confidenceBy2DJointName: confidenceBy2DJointName
                ),
                x: x,
                y: y,
                z: z
            ) else {
                continue
            }

            // Extract 2D image-space coordinates via pointInImage (normalized 0-1)
            var imageX: CGFloat?
            var imageY: CGFloat?
            if let imagePoint = try? observation.pointInImage(jointName) {
                let px = imagePoint.x
                let py = imagePoint.y
                if px.isFinite, py.isFinite,
                   (0...1).contains(px),
                   (0...1).contains(py) {
                    imageX = px
                    imageY = py
                }
            }

            positions.append(JointPosition3D(
                name: name, x: x, y: y, z: z,
                imageX: imageX, imageY: imageY
            ))
        }

        return positions
    }

    /// Extract joint positions from a 2D-only pose observation.
    /// Used as fallback when 3D detection fails (iPad front camera, unsupported devices).
    /// Coordinates are normalized (0-1) with z=0. Frontal metrics (shoulder/hip asymmetry,
    /// knee alignment) still produce meaningful relative comparisons.
    /// Sagittal metrics (forward head, rounded shoulders) will return "unmeasurable" (z=0).
    private static let tracked2DJoints: [(VNHumanBodyPoseObservation.JointName, String)] = [
        (.nose, "centerHead"),
        (.neck, "centerShoulder"),
        (.root, "root"),
        (.leftShoulder, "leftShoulder"),
        (.rightShoulder, "rightShoulder"),
        (.leftElbow, "leftElbow"),
        (.rightElbow, "rightElbow"),
        (.leftWrist, "leftWrist"),
        (.rightWrist, "rightWrist"),
        (.leftHip, "leftHip"),
        (.rightHip, "rightHip"),
        (.leftKnee, "leftKnee"),
        (.rightKnee, "rightKnee"),
        (.leftAnkle, "leftAnkle"),
        (.rightAnkle, "rightAnkle"),
    ]

    static func extractJointPositionsFrom2D(
        _ observation: VNHumanBodyPoseObservation
    ) -> [JointPosition3D] {
        var positions: [JointPosition3D] = []

        for (jointName, name) in tracked2DJoints {
            guard let point = try? observation.recognizedPoint(jointName),
                  point.confidence >= capturedJointMinimumConfidence else { continue }

            let loc = point.location  // normalized 0-1, origin bottom-left
            positions.append(JointPosition3D(
                name: name,
                x: Float(loc.x),
                y: Float(loc.y),
                z: 0,
                imageX: loc.x,
                imageY: loc.y
            ))
        }

        // Synthesize "spine" as midpoint between centerShoulder and root
        if let neck = positions.first(where: { $0.name == "centerShoulder" }),
           let root = positions.first(where: { $0.name == "root" }) {
            positions.append(JointPosition3D(
                name: "spine",
                x: (neck.x + root.x) / 2,
                y: (neck.y + root.y) / 2,
                z: 0,
                imageX: neck.imageX.flatMap { nx in root.imageX.map { rx in (nx + rx) / 2 } },
                imageY: neck.imageY.flatMap { ny in root.imageY.map { ry in (ny + ry) / 2 } }
            ))
        }

        return positions
    }

    private static func captureConfidenceBy2DJointName(
        from observation: VNHumanBodyPoseObservation?
    ) -> [VNHumanBodyPoseObservation.JointName: Float] {
        guard let observation else { return [:] }

        var confidenceByJointName: [VNHumanBodyPoseObservation.JointName: Float] = [:]
        for jointName in confidenceSourceJoints {
            guard let point = try? observation.recognizedPoint(jointName),
                  point.confidence.isFinite else {
                continue
            }
            confidenceByJointName[jointName] = point.confidence
        }

        return confidenceByJointName
    }

    static func capturedJointConfidence(
        for jointName: String,
        confidenceBy2DJointName: [VNHumanBodyPoseObservation.JointName: Float]
    ) -> Float? {
        switch jointName {
        case "topHead", "centerHead":
            return confidenceBy2DJointName[.nose]
        case "centerShoulder":
            return confidenceBy2DJointName[.neck]
        case "spine":
            return minConfidence(
                confidenceBy2DJointName[.neck],
                confidenceBy2DJointName[.root]
            )
        case "leftShoulder":
            return confidenceBy2DJointName[.leftShoulder]
        case "rightShoulder":
            return confidenceBy2DJointName[.rightShoulder]
        case "leftElbow":
            return confidenceBy2DJointName[.leftElbow]
        case "rightElbow":
            return confidenceBy2DJointName[.rightElbow]
        case "leftWrist":
            return confidenceBy2DJointName[.leftWrist]
        case "rightWrist":
            return confidenceBy2DJointName[.rightWrist]
        case "leftHip":
            return confidenceBy2DJointName[.leftHip]
        case "rightHip":
            return confidenceBy2DJointName[.rightHip]
        case "leftKnee":
            return confidenceBy2DJointName[.leftKnee]
        case "rightKnee":
            return confidenceBy2DJointName[.rightKnee]
        case "leftAnkle":
            return confidenceBy2DJointName[.leftAnkle]
        case "rightAnkle":
            return confidenceBy2DJointName[.rightAnkle]
        case "root":
            return confidenceBy2DJointName[.root]
        default:
            return nil
        }
    }

    private static func minConfidence(_ lhs: Float?, _ rhs: Float?) -> Float? {
        switch (lhs, rhs) {
        case let (.some(lhs), .some(rhs)):
            return min(lhs, rhs)
        case let (.some(lhs), .none):
            return lhs
        case let (.none, .some(rhs)):
            return rhs
        case (.none, .none):
            return nil
        }
    }

    static func shouldKeepCapturedJoint(
        confidence: Float?,
        x: Float,
        y: Float,
        z: Float
    ) -> Bool {
        guard x.isFinite && y.isFinite && z.isFinite else { return false }
        guard let confidence else { return false }
        return confidence >= capturedJointMinimumConfidence
    }

    // MARK: - Averaging

    private func averageResults(_ results: [PostureCaptureResult]) -> PostureCaptureResult {
        guard !results.isEmpty else {
            return PostureCaptureResult(
                jointPositions: [],
                bodyHeight: nil,
                heightEstimation: .reference,
                imageData: nil
            )
        }

        // Use the last frame's image (best quality after stabilization)
        let lastResult = results.last!

        // Average joint positions using median per axis
        let allJointNames = Set(results.flatMap { $0.jointPositions.map(\.name) })
        var averagedPositions: [JointPosition3D] = []

        for jointName in allJointNames {
            let matchingJoints = results.compactMap { result in
                result.jointPositions.first { $0.name == jointName }
            }

            guard matchingJoints.count >= 2 else {
                if let single = matchingJoints.first {
                    averagedPositions.append(single)
                }
                continue
            }

            let medianX = median(matchingJoints.map(\.x))
            let medianY = median(matchingJoints.map(\.y))
            let medianZ = median(matchingJoints.map(\.z))

            // Use last frame's 2D image coordinates (most recent camera pose)
            let lastImageX = matchingJoints.last?.imageX
            let lastImageY = matchingJoints.last?.imageY

            averagedPositions.append(
                JointPosition3D(
                    name: jointName, x: medianX, y: medianY, z: medianZ,
                    imageX: lastImageX, imageY: lastImageY
                )
            )
        }

        // Average body height
        let heights = results.compactMap(\.bodyHeight)
        let avgHeight = heights.isEmpty ? nil : heights.reduce(0, +) / Double(heights.count)

        return PostureCaptureResult(
            jointPositions: averagedPositions,
            bodyHeight: avgHeight,
            heightEstimation: lastResult.heightEstimation,
            imageData: lastResult.imageData
        )
    }

    private func median(_ values: [Float]) -> Float {
        let sorted = values.sorted()
        let count = sorted.count
        if count % 2 == 0 {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2.0
        } else {
            return sorted[count / 2]
        }
    }

    // MARK: - Orientation Extraction

    /// Extracts EXIF orientation from JPEG file data so Vision can return
    /// image-space coordinates in the displayed (portrait) coordinate system.
    private static func extractOrientation(from jpegData: Data?) -> CGImagePropertyOrientation {
        guard let data = jpegData,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let raw = properties[kCGImagePropertyOrientation as String] as? UInt32,
              let orientation = CGImagePropertyOrientation(rawValue: raw) else {
            return .up
        }
        return orientation
    }

    // MARK: - Image Compression

    private static let maxImageDimension: CGFloat = 1080

    private func compressImage(_ cgImage: CGImage) -> Data? {
        let uiImage = normalizedImage(UIImage(cgImage: cgImage))
        let scaled = downscaled(uiImage, maxDimension: Self.maxImageDimension)
        return encodePostureJPEG(scaled)
    }

    private func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else { return image }
        let scale = maxDimension / max(size.width, size.height)
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        return image.preparingThumbnail(of: targetSize) ?? image
    }

    /// Compresses oriented file data (from AVCapturePhoto.fileDataRepresentation())
    /// by decoding through UIImage to bake EXIF orientation into pixel data,
    /// then downscaling and re-encoding as JPEG.
    private func compressOrientedData(_ fileData: Data) -> Data? {
        guard let uiImage = UIImage(data: fileData) else {
            AppLogger.data.warning("[PostureCapture] compressOrientedData: failed to decode JPEG (\(fileData.count) bytes)")
            return nil
        }
        let flattened = normalizedImage(uiImage)
        let scaled = downscaled(flattened, maxDimension: Self.maxImageDimension)
        return encodePostureJPEG(scaled)
    }

    private func normalizedImage(_ image: UIImage) -> UIImage {
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 1
        return UIGraphicsImageRenderer(size: image.size, format: rendererFormat).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private func encodePostureJPEG(_ image: UIImage) -> Data? {
        guard let cgImage = image.cgImage else {
            return image.jpegData(compressionQuality: Self.jpegCompressionQuality)
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return image.jpegData(compressionQuality: Self.jpegCompressionQuality)
        }

        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: Self.jpegCompressionQuality,
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFSoftware: PostureImageMetadata.uprightJPEGSoftwareMarker,
            ],
        ]
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return image.jpegData(compressionQuality: Self.jpegCompressionQuality)
        }
        return data as Data
    }

    // MARK: - CGImage from Pool Buffer

    private static let fallbackCIContext = CIContext(options: [.useSoftwareRenderer: false])
    private static let bgraColorSpace = CGColorSpaceCreateDeviceRGB()

    /// Create a CGImage from a BGRA CVPixelBuffer via CPU memcpy.
    /// The resulting CGImage lives in heap memory — completely independent of
    /// the camera's IOSurface buffer pool. This eliminates TrueDepth (front camera)
    /// resource contention where Vision's ML buffer allocation competes with the
    /// depth sensor hardware for shared GPU/buffer resources.
    ///
    /// Performance: 720p BGRA = 3.6 MB memcpy ≈ 0.4 ms — well within 10fps budget.
    static func createCGImageFromBGRABuffer(_ pixelBuffer: CVPixelBuffer) -> CGImage? {
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        guard pixelFormat == kCVPixelFormatType_32BGRA else {
            // Non-BGRA: fall back to CIContext (slower but handles any format).
            // NOTE: this path still touches the IOSurface pool via CIImage(cvPixelBuffer:)
            // — not safe for TrueDepth front camera. Expected only on rear camera
            // historical formats where pool contention does not occur.
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            return fallbackCIContext.createCGImage(ciImage, from: ciImage.extent)
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        // Copy pixel data to heap — breaks IOSurface pool dependency.
        // Use CVPixelBufferGetDataSize for accurate size (accounts for padding).
        let byteCount = CVPixelBufferGetDataSize(pixelBuffer)
        let data = Data(bytes: baseAddress, count: byteCount)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }

        // 32BGRA = little-endian byte order, alpha channel in first byte (noneSkipFirst)
        let bitmapInfo = CGBitmapInfo(
            rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue
                | CGBitmapInfo.byteOrder32Little.rawValue
        )

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: bgraColorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    // MARK: - Pixel Buffer Copy

    /// Deep-copy a CVPixelBuffer so the original (owned by the camera pool) can
    /// be recycled immediately. Supports both planar (420YpCbCr) and interleaved formats.
    static func copyPixelBuffer(_ source: CVPixelBuffer) -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(source)
        let height = CVPixelBufferGetHeight(source)
        let format = CVPixelBufferGetPixelFormatType(source)

        var copy: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, width, height, format,
            nil, // plain heap — no IOSurface overhead for CPU-only use
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

    private func configurePhotoConnectionForCurrentOrientation() {
        guard let connection = photoOutput.connection(with: .video) else { return }

        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = currentPosition == .front

        let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelCapture ?? 0
        guard connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle
    }

    private var liveDeviceOrientation: UIDeviceOrientation {
        orientationLock.withLock { currentDeviceOrientation }
    }

    private var livePreviewRotationAngle: CGFloat? {
        orientationLock.withLock { currentPreviewRotationAngle }
    }

    private static func isInterfaceOrientation(_ orientation: UIDeviceOrientation) -> Bool {
        switch orientation {
        case .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight:
            return true
        default:
            return false
        }
    }

    private static func liveVisionOrientation(for orientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .portraitUpsideDown:
            return .left
        case .landscapeLeft:
            return .up
        case .landscapeRight:
            return .down
        case .portrait:
            return .right
        default:
            return .right
        }
    }

    private static func liveVisionOrientation(forPreviewRotationAngle angle: CGFloat) -> CGImagePropertyOrientation {
        switch Int(normalizedRightAngle(from: angle)) {
        case 0:
            return .up
        case 180:
            return .down
        case 270:
            return .left
        default:
            return .right
        }
    }

    private static func normalizedRightAngle(from angle: CGFloat) -> CGFloat {
        let normalized = angle.truncatingRemainder(dividingBy: 360)
        let positive = normalized < 0 ? normalized + 360 : normalized
        return (positive / 90).rounded() * 90
    }

    private static func orientedImageSize(
        for size: CGSize,
        orientation: CGImagePropertyOrientation
    ) -> CGSize {
        switch orientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            return CGSize(width: size.height, height: size.width)
        default:
            return size
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension PostureCaptureService: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: (any Error)?
    ) {
        let continuation = continuationLock.withLock { () -> CheckedContinuation<(CGImage, Data?), any Error>? in
            let c = photoContinuation
            photoContinuation = nil
            return c
        }
        if let error {
            continuation?.resume(throwing: error)
        } else if let cgImage = photo.cgImageRepresentation() {
            // Pass raw file data (with EXIF orientation) for deferred compression
            // outside the delegate callback to reduce peak memory on the AVFoundation queue.
            let fileData = photo.fileDataRepresentation()
            continuation?.resume(returning: (cgImage, fileData))
        } else {
            continuation?.resume(throwing: PostureCaptureError.imageConversionFailed)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate (Real-time 2D Pose)

extension PostureCaptureService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Throttle to ~10fps
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastFrameAnalysisTime >= Self.frameAnalysisInterval else { return }
        lastFrameAnalysisTime = now

        guard let poolBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard onFrameUpdate != nil || onRealtimeFrame != nil else { return }

        let rawImageSize = CGSize(
            width: CVPixelBufferGetWidth(poolBuffer),
            height: CVPixelBufferGetHeight(poolBuffer)
        )
        let pixelFormat = Self.pixelFormatLabel(CVPixelBufferGetPixelFormatType(poolBuffer))

        let orientation: CGImagePropertyOrientation
        if let previewRotationAngle = livePreviewRotationAngle {
            orientation = Self.liveVisionOrientation(
                forPreviewRotationAngle: previewRotationAngle
            )
        } else {
            orientation = Self.liveVisionOrientation(for: liveDeviceOrientation)
        }

        // Luminance from pool buffer (fast, no ML, ~instant)
        let luminance = Self.averageLuminance(from: poolBuffer)

        // --- 2D detection: CGImage to decouple from camera pool ---
        // On front camera (TrueDepth), Vision's perform() with IOSurface-backed pool
        // buffers fails because the depth sensor hardware consumes shared GPU/buffer
        // resources. Even BGRA format doesn't fully solve this — Vision's ML inference
        // still allocates internal buffers from the same shared pool.
        // Creating a CGImage via CPU memcpy decouples Vision from the camera pool entirely.
        // Skip this frame if 3D Vision is running (shared internal ML buffer pool).
        guard visionSemaphore.wait(timeout: .now()) == .success else { return }
        guard let cgImage = Self.createCGImageFromBGRABuffer(poolBuffer) else {
            visionSemaphore.signal()
            return
        }
        // Pool buffer is no longer needed — released when sampleBuffer goes out of scope.

        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: orientation,
            options: [:]
        )
        let requestStart = CFAbsoluteTimeGetCurrent()

        do {
            try handler.perform([bodyPoseRequest])
            visionSemaphore.signal()
        } catch {
            visionSemaphore.signal()
            livePoseErrorCount += 1
            publishDiagnostics(
                frameWidth: Int(rawImageSize.width),
                frameHeight: Int(rawImageSize.height),
                pixelFormat: pixelFormat,
                lastPoseLatencyMs: Int((CFAbsoluteTimeGetCurrent() - requestStart) * 1000),
                lastVisionError: error.localizedDescription
            )
            return
        }
        let requestLatencyMs = Int((CFAbsoluteTimeGetCurrent() - requestStart) * 1000)

        let observation = bodyPoseRequest.results?.first

        // Extract 2D keypoints for skeleton overlay
        var keypoints: [(String, CGPoint)] = []
        if let observation {
            let jointNames: [(VNHumanBodyPoseObservation.JointName, String)] = [
                (.nose, "nose"),
                (.leftShoulder, "leftShoulder"), (.rightShoulder, "rightShoulder"),
                (.leftElbow, "leftElbow"), (.rightElbow, "rightElbow"),
                (.leftWrist, "leftWrist"), (.rightWrist, "rightWrist"),
                (.leftHip, "leftHip"), (.rightHip, "rightHip"),
                (.leftKnee, "leftKnee"), (.rightKnee, "rightKnee"),
                (.leftAnkle, "leftAnkle"), (.rightAnkle, "rightAnkle"),
            ]
            for (jointName, name) in jointNames {
                if let point = try? observation.recognizedPoint(jointName),
                   point.confidence >= Self.previewJointMinimumConfidence {
                    // Vision normalized: origin bottom-left (0,0) to top-right (1,1)
                    keypoints.append((name, point.location))
                }
            }
        }

        // Update guidance state
        let state = guidanceAnalyzer.analyze(
            observation: observation,
            keypoints: keypoints,
            luminance: luminance
        )

        let orientedImageSize = Self.orientedImageSize(for: rawImageSize, orientation: orientation)

        onFrameUpdate?(state, keypoints, orientedImageSize)
        publishDiagnostics(
            frameWidth: Int(rawImageSize.width),
            frameHeight: Int(rawImageSize.height),
            pixelFormat: pixelFormat,
            lastPoseLatencyMs: requestLatencyMs,
            lastVisionError: nil
        )

        // --- 3D sampling: reuse CGImage at throttled rate (~4fps) ---
        var cgImageFor3D: CGImage?
        if !keypoints.isEmpty, onRealtimeFrame != nil,
           now - last3DSamplingTime >= Self.threeDSamplingInterval {
            last3DSamplingTime = now
            cgImageFor3D = cgImage
        }
        onRealtimeFrame?(keypoints, cgImageFor3D)
    }

    /// Compute average luminance from either the Y plane (420f/420v) or RGB channels (BGRA).
    static func averageLuminance(from pixelBuffer: CVPixelBuffer) -> Double {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let planeCount = CVPixelBufferGetPlaneCount(pixelBuffer)
        if planeCount > 0,
           let baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) {
            let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
            let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
            let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)

            let stride = 16
            var totalLuminance: UInt64 = 0
            var sampleCount: UInt64 = 0

            let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
            var y = 0
            while y < height {
                var x = 0
                while x < width {
                    totalLuminance += UInt64(buffer[y * bytesPerRow + x])
                    sampleCount += 1
                    x += stride
                }
                y += stride
            }

            guard sampleCount > 0 else { return 0.5 }
            return Double(totalLuminance) / Double(sampleCount) / 255.0
        }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return 0.5
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let stride = 16
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        var totalLuminance = 0.0
        var sampleCount = 0.0
        var y = 0
        while y < height {
            var x = 0
            while x < width {
                let offset = y * bytesPerRow + x * 4
                let blue = Double(buffer[offset])
                let green = Double(buffer[offset + 1])
                let red = Double(buffer[offset + 2])
                totalLuminance += (0.0722 * blue + 0.7152 * green + 0.2126 * red) / 255.0
                sampleCount += 1
                x += stride
            }
            y += stride
        }

        guard sampleCount > 0 else { return 0.5 }
        return totalLuminance / sampleCount
    }

    private func applyLiveVideoOutputConfiguration() {
        let availableFormats = videoDataOutput.availableVideoPixelFormatTypes

        // Force BGRA when user hasn't explicitly chosen a format.
        // Vision's ML pipeline requires BGRA buffers. When the camera delivers YUV,
        // Vision tries to create an internal "mlImage buffer of type BGRA" for conversion.
        // On front camera (TrueDepth), this internal allocation fails because the depth
        // sensor hardware consumes shared GPU/buffer resources.
        // By requesting BGRA directly, the camera hardware handles the conversion and
        // Vision can use the buffer as-is — no internal mlImage buffer needed.
        let format: OSType?
        if liveConfiguration.pixelFormat == .automatic {
            if availableFormats.contains(kCVPixelFormatType_32BGRA) {
                format = kCVPixelFormatType_32BGRA
            } else {
                format = PostureCaptureLivePixelFormatOption.preferredNativeFormat(from: availableFormats)
            }
        } else {
            format = liveConfiguration.pixelFormat.resolvedFormat(from: availableFormats)
        }

        if let format {
            videoDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(format),
            ]
        } else {
            videoDataOutput.videoSettings = [:]
        }
    }

    private static func pixelFormatLabel(_ format: OSType) -> String {
        switch format {
        case kCVPixelFormatType_32BGRA:
            return "32BGRA"
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
            return "420f"
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            return "420v"
        default:
            return String(format: "0x%08X", format)
        }
    }

    private func publishDiagnostics(
        frameWidth: Int,
        frameHeight: Int,
        pixelFormat: String,
        lastPoseLatencyMs: Int,
        lastVisionError: String?
    ) {
        let diagnostics = PostureCaptureDiagnostics(
            configuredPreset: liveConfiguration.preset.displayLabel,
            configuredPixelFormat: liveConfiguration.pixelFormat.displayLabel,
            sessionPreset: captureSession.sessionPreset.rawValue,
            frameWidth: frameWidth,
            frameHeight: frameHeight,
            pixelFormat: pixelFormat,
            lastPoseLatencyMs: lastPoseLatencyMs,
            poseErrorCount: livePoseErrorCount,
            lastVisionError: lastVisionError
        )
        onDiagnosticsUpdate?(diagnostics)
        guard Self.isDiagnosticsEnabled else { return }
        if let lastVisionError {
            AppLogger.data.error("[PostureCapture] live pose failed cfgPreset=\(diagnostics.configuredPreset) cfgFormat=\(diagnostics.configuredPixelFormat) preset=\(diagnostics.sessionPreset) frame=\(frameWidth)x\(frameHeight) format=\(pixelFormat) latency=\(lastPoseLatencyMs)ms errors=\(self.livePoseErrorCount) message=\(lastVisionError)")
        } else {
            AppLogger.data.debug("[PostureCapture] live pose cfgPreset=\(diagnostics.configuredPreset) cfgFormat=\(diagnostics.configuredPixelFormat) preset=\(diagnostics.sessionPreset) frame=\(frameWidth)x\(frameHeight) format=\(pixelFormat) latency=\(lastPoseLatencyMs)ms errors=\(self.livePoseErrorCount)")
        }
    }
}
#endif
