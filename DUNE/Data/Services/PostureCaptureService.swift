#if !os(visionOS)
import AVFoundation
import Foundation
import os
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
    private var photoContinuation: CheckedContinuation<(CGImage, Data?), any Error>?

    // MARK: - Real-time Guidance

    private let guidanceAnalyzer = PostureGuidanceAnalyzer()
    private let bodyPoseRequest = VNDetectHumanBodyPoseRequest()
    // Accessed only on videoDataQueue (single serial queue) — no lock needed.
    private var lastFrameAnalysisTime: CFAbsoluteTime = 0
    private static let frameAnalysisInterval: CFAbsoluteTime = 0.1 // 10fps max
    /// Combined frame update callback: guidance state + skeleton keypoints in a single dispatch.
    var onFrameUpdate: (@Sendable (GuidanceState, [(String, CGPoint)]) -> Void)?

    // MARK: - Camera State

    private(set) var currentPosition: AVCaptureDevice.Position = .front

    // MARK: - Configuration

    private static let minimumConfidence: Float = 0.3
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
            // Rotate video frames to portrait so Vision coordinates match preview orientation
            if let connection = videoDataOutput.connection(with: .video) {
                connection.videoRotationAngle = 90
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
        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        guard let observation = request.results?.first else {
            throw PostureCaptureError.noPoseDetected
        }

        let jointPositions = extractJointPositions(from: observation)

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

    private func extractJointPositions(
        from observation: VNHumanBodyPose3DObservation
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

            guard x.isFinite, y.isFinite, z.isFinite else { continue }

            // Extract 2D image-space coordinates via pointInImage (normalized 0-1)
            var imageX: CGFloat?
            var imageY: CGFloat?
            if let imagePoint = try? observation.pointInImage(jointName) {
                let px = imagePoint.x
                let py = imagePoint.y
                if px.isFinite, py.isFinite {
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

    // MARK: - Image Compression

    private static let maxImageDimension: CGFloat = 1080

    private func compressImage(_ cgImage: CGImage) -> Data? {
        let uiImage = UIImage(cgImage: cgImage)
        let scaled = downscaled(uiImage, maxDimension: Self.maxImageDimension)
        return scaled.jpegData(compressionQuality: Self.jpegCompressionQuality)
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
        let scaled = downscaled(uiImage, maxDimension: Self.maxImageDimension)
        return scaled.jpegData(compressionQuality: Self.jpegCompressionQuality)
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

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

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
                   point.confidence > 0.3 {
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

        onFrameUpdate?(state, keypoints)
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
