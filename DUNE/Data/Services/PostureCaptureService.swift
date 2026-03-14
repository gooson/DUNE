import AVFoundation
import Foundation
import UIKit
import Vision

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
    private var photoContinuation: CheckedContinuation<AVCapturePhoto, any Error>?

    // MARK: - Configuration

    private static let minimumConfidence: Float = 0.3
    private static let jpegCompressionQuality: CGFloat = 0.7
    private static let referenceBodyHeight: Double = 1.8

    // MARK: - Setup

    func setupCamera() throws {
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        ) else {
            throw PostureCaptureError.cameraUnavailable
        }

        let input = try AVCaptureDeviceInput(device: device)

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo

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

        captureSession.commitConfiguration()
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

    func capturePhoto() async throws -> AVCapturePhoto {
        guard captureSession.isRunning else {
            throw PostureCaptureError.captureSessionNotRunning
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.photoContinuation = continuation
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    // MARK: - Pose Detection

    func detectPose(from image: CGImage) async throws -> PostureCaptureResult {
        let request = DetectHumanBodyPose3DRequest()
        let observations = try await request.perform(on: image)

        guard let observation = observations.first else {
            throw PostureCaptureError.noPoseDetected
        }

        let jointPositions = extractJointPositions(from: observation)

        guard !jointPositions.isEmpty else {
            throw PostureCaptureError.insufficientConfidence
        }

        let bodyHeight: Double?
        let heightEstimation: HeightEstimationType

        if let height = try? observation.bodyHeight,
           height.isFinite, height > 0.5, height < 2.5 {
            bodyHeight = Double(height)
            heightEstimation = .measured
        } else {
            bodyHeight = Self.referenceBodyHeight
            heightEstimation = .reference
        }

        let imageData = compressImage(image)

        return PostureCaptureResult(
            jointPositions: jointPositions,
            bodyHeight: bodyHeight,
            heightEstimation: heightEstimation,
            imageData: imageData
        )
    }

    // MARK: - Full Capture Pipeline

    func captureAndDetect() async throws -> PostureCaptureResult {
        let photo = try await capturePhoto()

        guard let cgImage = photo.cgImageRepresentation() else {
            throw PostureCaptureError.imageConversionFailed
        }

        return try await detectPose(from: cgImage)
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

    private static let trackedJoints: [(HumanBodyPose3DObservation.JointName, String)] = [
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
        from observation: HumanBodyPose3DObservation
    ) -> [JointPosition3D] {
        var positions: [JointPosition3D] = []

        for (jointName, name) in Self.trackedJoints {
            guard let point = try? observation.recognizedPoint(jointName) else {
                continue
            }

            // position is simd_float4x4 — translation in columns.3
            let translation = point.position.columns.3
            let x = translation.x
            let y = translation.y
            let z = translation.z

            guard x.isFinite, y.isFinite, z.isFinite else { continue }

            positions.append(JointPosition3D(name: name, x: x, y: y, z: z))
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

            averagedPositions.append(
                JointPosition3D(name: jointName, x: medianX, y: medianY, z: medianZ)
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

    private func compressImage(_ cgImage: CGImage) -> Data? {
        let uiImage = UIImage(cgImage: cgImage)
        return uiImage.jpegData(compressionQuality: Self.jpegCompressionQuality)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension PostureCaptureService: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: (any Error)?
    ) {
        if let error {
            photoContinuation?.resume(throwing: error)
        } else {
            photoContinuation?.resume(returning: photo)
        }
        photoContinuation = nil
    }
}
