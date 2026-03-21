import CoreVideo
import Foundation
import Testing

@testable import DUNE

@Suite("PostureCaptureService")
struct PostureCaptureServiceTests {

    @Test("Average luminance reads the Y plane for NV12 buffers")
    func averageLuminanceNV12() throws {
        let pixelBuffer = try makeNV12Buffer(width: 32, height: 32, yValue: 64)

        let luminance = PostureCaptureService.averageLuminance(from: pixelBuffer)

        #expect(abs(luminance - (64.0 / 255.0)) < 0.05)
    }

    @Test("Average luminance falls back to BGRA channel sampling")
    func averageLuminanceBGRA() throws {
        let pixelBuffer = try makeBGRABuffer(width: 32, height: 32, red: 255, green: 255, blue: 255)

        let luminance = PostureCaptureService.averageLuminance(from: pixelBuffer)

        #expect(luminance > 0.95)
    }

    @Test("Live configuration parses posture capture launch arguments")
    func liveConfigurationLaunchArguments() {
        let configuration = PostureCaptureLiveConfiguration.current(
            arguments: [
                "--posture-open-capture",
                "--posture-live-preset", "photo",
                "--posture-live-format", "bgra",
            ]
        )

        #expect(configuration.preset == .photo)
        #expect(configuration.pixelFormat == .bgra)
    }

    @Test("Automatic live pixel format prefers native YUV over BGRA")
    func automaticLivePixelFormatPrefersNativeYUV() {
        let format = PostureCaptureLivePixelFormatOption.automatic.resolvedFormat(
            from: [
                kCVPixelFormatType_32BGRA,
                kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            ]
        )

        #expect(format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
    }

    @Test("Requested BGRA falls back to YUV when BGRA is unavailable")
    func requestedBGRAPixelFormatFallsBackToNativeYUV() {
        let format = PostureCaptureLivePixelFormatOption.bgra.resolvedFormat(
            from: [
                kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            ]
        )

        #expect(format == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
    }

    @Test("Capture result reports whether a true 3D pose was produced")
    func captureResultTracksTrue3DPose() {
        let threeDResult = PostureCaptureResult(
            jointPositions: [],
            bodyHeight: 1.8,
            heightEstimation: .measured,
            imageData: nil,
            poseSource: .threeD
        )
        let fallbackResult = PostureCaptureResult(
            jointPositions: [],
            bodyHeight: 1.8,
            heightEstimation: .reference,
            imageData: nil,
            poseSource: .twoDFallback
        )

        #expect(threeDResult.hasTrue3DPose)
        #expect(!fallbackResult.hasTrue3DPose)
    }

    @Test("Averaged pose source stays in fallback mode when any sample is 2D fallback")
    func averagedPoseSourceIsConservative() {
        let mixedSources = [
            PostureCaptureResult(
                jointPositions: [],
                bodyHeight: 1.8,
                heightEstimation: .measured,
                imageData: nil,
                poseSource: .threeD
            ),
            PostureCaptureResult(
                jointPositions: [],
                bodyHeight: 1.8,
                heightEstimation: .reference,
                imageData: nil,
                poseSource: .twoDFallback
            ),
        ]

        #expect(PostureCaptureResult.averagedPoseSource(for: []) == .twoDFallback)
        #expect(PostureCaptureResult.averagedPoseSource(for: mixedSources) == .twoDFallback)
        #expect(
            PostureCaptureResult.averagedPoseSource(
                for: [
                    PostureCaptureResult(
                        jointPositions: [],
                        bodyHeight: 1.8,
                        heightEstimation: .measured,
                        imageData: nil,
                        poseSource: .threeD
                    ),
                    PostureCaptureResult(
                        jointPositions: [],
                        bodyHeight: 1.75,
                        heightEstimation: .reference,
                        imageData: nil,
                        poseSource: .threeD
                    ),
                ]
            ) == .threeD
        )
    }

    // MARK: - Helpers

    private func makeNV12Buffer(width: Int, height: Int, yValue: UInt8) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            attributes as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw TestError.createPixelBufferFailed
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let yBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0),
              let uvBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1) else {
            throw TestError.missingBaseAddress
        }

        let yBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let uvBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)
        memset(yBaseAddress, Int32(yValue), yBytesPerRow * height)
        memset(uvBaseAddress, 128, uvBytesPerRow * max(height / 2, 1))
        return pixelBuffer
    }

    private func makeBGRABuffer(
        width: Int,
        height: Int,
        red: UInt8,
        green: UInt8,
        blue: UInt8
    ) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw TestError.createPixelBufferFailed
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw TestError.missingBaseAddress
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                buffer[offset] = blue
                buffer[offset + 1] = green
                buffer[offset + 2] = red
                buffer[offset + 3] = 255
            }
        }

        return pixelBuffer
    }

    private enum TestError: Error {
        case createPixelBufferFailed
        case missingBaseAddress
    }
}
