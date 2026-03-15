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
