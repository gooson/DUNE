#if !os(visionOS)
import AVFoundation
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

// MARK: - PostureCaptureService

final class PostureCaptureService: NSObject, PostureCapturing, @unchecked Sendable {

    // MARK: - Camera Session

    let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let videoDataQueue = DispatchQueue(label: "com.dune.posture.videoData", qos: .userInitiated)
    private let continuationLock = NSLock()
    private let orientationLock = NSLock()
    private var photoContinuation: CheckedContinuation<(CGImage, Data?), any Error>?
    private var currentDeviceOrientation: UIDeviceOrientation = .portrait
    private var currentPreviewRotationAngle: CGFloat?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?

    // MARK: - Real-time Guidance

    private let guidanceAnalyzer = PostureGuidanceAnalyzer()
    private let bodyPoseRequest = VNDetectHumanBodyPoseRequest()
    // Accessed only on videoDataQueue (single serial queue) — no lock needed.
    private var lastFrameAnalysisTime: CFAbsoluteTime = 0
    private static let frameAnalysisInterval: CFAbsoluteTime = 0.1 // 10fps max
    /// Combined frame update callback: guidance state + skeleton keypoints in a single dispatch.
    var onFrameUpdate: (@Sendable (GuidanceState, [(String, CGPoint)], CGSize) -> Void)?
    /// Realtime analysis callback: keypoints + sample buffer for 3D sampling.
    /// CMSampleBuffer retains the underlying pixel buffer, preventing pool recycling.
    var onRealtimeFrame: (@Sendable ([(String, CGPoint)], CMSampleBuffer) -> Void)?

    // MARK: - Camera State

    private(set) var currentPosition: AVCaptureDevice.Position = .front
    private(set) var currentDevice: AVCaptureDevice?

    // MARK: - Configuration

    // Final captures use a stricter threshold than live guidance so weak
    // outliers do not leak into the saved overlay or posture analysis.
    static let capturedJointMinimumConfidence: Float = 0.5
    private static let previewJointMinimumConfidence: Float = 0.3
    private static let jpegCompressionQuality: CGFloat = 0.7
    private static let referenceBodyHeight: Double = 1.8

    // MARK: - Setup

    func setupCamera(position: AVCaptureDevice.Position = .front) throws {
        // Drain any leaked photoContinuation from a previous session
        continuationLock.withLock {
            photoContinuation?.resume(throwing: PostureCaptureError.captureSessionNotRunning)
            photoContinuation = nil
        }

        currentPosition = position
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
        captureSession.sessionPreset = .photo

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

        guard captureSession.canAddOutput(photoOutput) else {
            captureSession.commitConfiguration()
            throw PostureCaptureError.cameraUnavailable
        }
        captureSession.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .quality

        // Add video data output for real-time pose guidance
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataQueue)
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
            if let connection = videoDataOutput.connection(with: .video) {
                // Keep raw video-data buffers in native sensor orientation and let
                // Vision apply explicit orientation metadata per frame.
                connection.videoRotationAngle = 0
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
        }

        captureSession.commitConfiguration()
    }

    func switchCamera() throws {
        let newPosition: AVCaptureDevice.Position = currentPosition == .front ? .back : .front
        try setupCamera(position: newPosition)
    }

    func startSession() {
        guard !captureSession.isRunning else { return }
        captureSession.startRunning()
    }

    func stopSession() {
        guard captureSession.isRunning else { return }
        captureSession.stopRunning()
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
        let request = VNDetectHumanBodyPose3DRequest()
        let confidenceRequest = VNDetectHumanBodyPoseRequest()
        // Pass EXIF orientation so pointInImage() returns coordinates in the
        // displayed (portrait, mirrored-for-front-camera) coordinate space,
        // not in the raw landscape sensor coordinate space.
        let orientation = Self.extractOrientation(from: orientedJPEG)
        let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request, confidenceRequest])
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        guard let observation = request.results?.first else {
            throw PostureCaptureError.noPoseDetected
        }

        let confidenceBy2DJointName = Self.captureConfidenceBy2DJointName(
            from: confidenceRequest.results?.first
        )
        let jointPositions = extractJointPositions(
            from: observation,
            confidenceBy2DJointName: confidenceBy2DJointName
        )

        guard !jointPositions.isEmpty else {
            throw PostureCaptureError.insufficientConfidence
        }

        let bodyHeight: Double?
        let heightEstimation: HeightEstimationType

        let height = observation.bodyHeight
        if height.isFinite, height > 0.5, height < 2.5 {
            bodyHeight = Double(height)
            heightEstimation = .measured
        } else {
            bodyHeight = Self.referenceBodyHeight
            heightEstimation = .reference
        }

        // Compress oriented file data (preserves correct orientation) off the delegate callback,
        // or fall back to compressing the raw CGImage for the external API path
        let imageData: Data? = if let orientedJPEG {
            compressOrientedData(orientedJPEG)
        } else {
            compressImage(image)
        }

        return PostureCaptureResult(
            jointPositions: jointPositions,
            bodyHeight: bodyHeight,
            heightEstimation: heightEstimation,
            imageData: imageData
        )
    }

    // MARK: - 3D Pose Detection from Video Frame

    /// Detect 3D pose from a copied pixel buffer. Caller must pass a buffer that is NOT
    /// backed by the AVCaptureSession pool so the camera can continue recycling frames.
    func detectPoseFromVideoFrame(_ pixelBuffer: CVPixelBuffer) async throws -> PostureCaptureResult {
        let request = VNDetectHumanBodyPose3DRequest()
        let confidenceRequest = VNDetectHumanBodyPoseRequest()
        // No EXIF orientation for live video frames (already rotated by connection.videoRotationAngle)
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request, confidenceRequest])
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        guard let observation = request.results?.first else {
            throw PostureCaptureError.noPoseDetected
        }

        let confidenceBy2DJointName = Self.captureConfidenceBy2DJointName(
            from: confidenceRequest.results?.first
        )
        let jointPositions = extractJointPositions(
            from: observation,
            confidenceBy2DJointName: confidenceBy2DJointName
        )

        guard !jointPositions.isEmpty else {
            throw PostureCaptureError.insufficientConfidence
        }

        let bodyHeight: Double?
        let heightEstimation: HeightEstimationType

        let height = observation.bodyHeight
        if height.isFinite, height > 0.5, height < 2.5 {
            bodyHeight = Double(height)
            heightEstimation = .measured
        } else {
            bodyHeight = Self.referenceBodyHeight
            heightEstimation = .reference
        }

        return PostureCaptureResult(
            jointPositions: jointPositions,
            bodyHeight: bodyHeight,
            heightEstimation: heightEstimation,
            imageData: nil
        )
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

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let orientation: CGImagePropertyOrientation
        if let previewRotationAngle = livePreviewRotationAngle {
            orientation = Self.liveVisionOrientation(
                forPreviewRotationAngle: previewRotationAngle
            )
        } else {
            orientation = Self.liveVisionOrientation(for: liveDeviceOrientation)
        }
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: orientation,
            options: [:]
        )

        do {
            try handler.perform([bodyPoseRequest])
        } catch {
            return
        }

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

        // Compute luminance from pixel buffer
        let luminance = averageLuminance(from: pixelBuffer)

        // Update guidance state
        let state = guidanceAnalyzer.analyze(
            observation: observation,
            keypoints: keypoints,
            luminance: luminance
        )

        let rawImageSize = CGSize(
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer)
        )
        let orientedImageSize = Self.orientedImageSize(for: rawImageSize, orientation: orientation)

        onFrameUpdate?(state, keypoints, orientedImageSize)
        onRealtimeFrame?(keypoints, sampleBuffer)
    }

    /// Compute average luminance from Y plane of pixel buffer.
    private func averageLuminance(from pixelBuffer: CVPixelBuffer) -> Double {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else {
            return 0.5
        }

        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)

        // Sample every 16th pixel for performance
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
}
#endif
