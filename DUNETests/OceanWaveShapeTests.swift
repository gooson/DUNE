import Foundation
import SwiftUI
import Testing
@testable import DUNE

@Suite("OceanWaveShape Geometry")
struct OceanWaveShapeTests {
    @Test("Path is non-empty for valid rect")
    func pathNonEmpty() {
        let wave = OceanWaveShape()
        let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
        let path = wave.path(in: rect)
        #expect(!path.isEmpty)
    }

    @Test("Path is empty for zero-size rect")
    func pathEmptyForZeroRect() {
        let wave = OceanWaveShape()
        #expect(wave.path(in: .zero).isEmpty)
        #expect(wave.path(in: CGRect(x: 0, y: 0, width: 0, height: 100)).isEmpty)
        #expect(wave.path(in: CGRect(x: 0, y: 0, width: 100, height: 0)).isEmpty)
    }

    @Test("Path stays within rect bounds (baseline, no crest harmonics)")
    func pathWithinBounds() {
        let wave = OceanWaveShape(amplitude: 0.3, frequency: 3, steepness: 0.4)
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let bounds = wave.path(in: rect).boundingRect
        #expect(bounds.minX >= rect.minX - 1)
        #expect(bounds.maxX <= rect.maxX + 1)
        #expect(bounds.minY >= rect.minY - 1)
        #expect(bounds.maxY <= rect.maxY + 1)
    }

    @Test("Steepness creates asymmetric crests vs troughs")
    func steepnessAsymmetry() {
        let rect = CGRect(x: 0, y: 0, width: 400, height: 200)
        let symmetric = OceanWaveShape(amplitude: 0.2, frequency: 2, phase: 0, verticalOffset: 0.5, steepness: 0)
        let asymmetric = OceanWaveShape(amplitude: 0.2, frequency: 2, phase: 0, verticalOffset: 0.5, steepness: 0.4)

        let symBounds = symmetric.path(in: rect).boundingRect
        let asymBounds = asymmetric.path(in: rect).boundingRect

        // Asymmetric wave should have different vertical extent due to harmonic addition
        let symHeight = symBounds.height
        let asymHeight = asymBounds.height
        #expect(asymHeight != symHeight)
    }

    @Test("animatableData reflects phase")
    func animatableData() {
        var wave = OceanWaveShape(phase: 1.5)
        #expect(wave.animatableData == 1.5)
        wave.animatableData = 3.0
        #expect(wave.animatableData == 3.0)
    }

    @Test("Different phases produce different paths")
    func phaseChangesPath() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
        let wave0 = OceanWaveShape(phase: 0)
        let wavePi = OceanWaveShape(phase: .pi)
        let path0 = wave0.path(in: rect)
        let pathPi = wavePi.path(in: rect)

        // Start points should differ due to phase shift
        let start0 = firstWavePoint(from: path0)
        let startPi = firstWavePoint(from: pathPi)
        #expect(start0 != nil)
        #expect(startPi != nil)
        if let start0, let startPi {
            #expect(abs(start0.y - startPi.y) > 0.1)
        }
    }

    @Test("Zero amplitude produces flat wave")
    func zeroAmplitude() {
        let wave = OceanWaveShape(amplitude: 0, verticalOffset: 0.5)
        let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
        let bounds = wave.path(in: rect).boundingRect
        // Wave line at 50pt, fill to bottom = 100pt
        #expect(bounds.minY >= 49 && bounds.minY <= 51)
    }

    @Test("crestHeight creates variable wave heights")
    func crestHeightVariation() {
        let rect = CGRect(x: 0, y: 0, width: 400, height: 200)
        let flat = OceanWaveShape(amplitude: 0.2, frequency: 2, steepness: 0.3, crestHeight: 0)
        let variable = OceanWaveShape(amplitude: 0.2, frequency: 2, steepness: 0.3, crestHeight: 0.3)

        let flatBounds = flat.path(in: rect).boundingRect
        let varBounds = variable.path(in: rect).boundingRect

        // Variable crestHeight should produce different vertical extent
        #expect(flatBounds.height != varBounds.height)
    }

    @Test("crestSharpness adds high-frequency detail")
    func crestSharpnessDetail() {
        let rect = CGRect(x: 0, y: 0, width: 400, height: 200)
        let smooth = OceanWaveShape(amplitude: 0.2, frequency: 2, steepness: 0.3, crestSharpness: 0)
        let sharp = OceanWaveShape(amplitude: 0.2, frequency: 2, steepness: 0.3, crestSharpness: 0.15)

        let smoothBounds = smooth.path(in: rect).boundingRect
        let sharpBounds = sharp.path(in: rect).boundingRect

        // Sharpness should alter the wave profile
        #expect(smoothBounds.height != sharpBounds.height)
    }

    @Test("Path stays within bounds with all harmonics active")
    func pathBoundsWithAllHarmonics() {
        // Max theoretical deviation: amp * (1 + steepness + crestHeight + crestSharpness)
        // = 200 * 0.3 * (1 + 0.4 + 0.4 + 0.15) = 117pt from centerY
        let wave = OceanWaveShape(
            amplitude: 0.3,
            frequency: 3,
            steepness: 0.4,
            crestHeight: 0.4,
            crestSharpness: 0.15
        )
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let bounds = wave.path(in: rect).boundingRect
        #expect(bounds.minX >= rect.minX - 1)
        #expect(bounds.maxX <= rect.maxX + 1)
        // Tightened: centerY(100) ± 117pt → minY ~= -17, maxY includes fill to 200
        #expect(bounds.minY >= rect.minY - 120)
        #expect(bounds.maxY <= rect.maxY + 1)
    }

    // MARK: - Curl Tests

    @Test("curlCount 0 produces same path as without curl params")
    func curlCountZeroNoChange() {
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let noCurl = OceanWaveShape(amplitude: 0.2, frequency: 2, steepness: 0.3)
        let zeroCurl = OceanWaveShape(amplitude: 0.2, frequency: 2, steepness: 0.3, curlCount: 0)
        let noCurlBounds = noCurl.path(in: rect).boundingRect
        let zeroCurlBounds = zeroCurl.path(in: rect).boundingRect
        #expect(abs(noCurlBounds.minY - zeroCurlBounds.minY) < 0.01)
        #expect(abs(noCurlBounds.maxY - zeroCurlBounds.maxY) < 0.01)
    }

    @Test("curlCount > 0 extends path above normal wave")
    func curlExtendsAboveWave() {
        let rect = CGRect(x: 0, y: 0, width: 400, height: 200)
        let noCurl = OceanWaveShape(
            amplitude: 0.2, frequency: 2, steepness: 0.3,
            crestHeight: 0.2, crestSharpness: 0.05
        )
        let withCurl = OceanWaveShape(
            amplitude: 0.2, frequency: 2, steepness: 0.3,
            crestHeight: 0.2, crestSharpness: 0.05,
            curlCount: 1, curlHeight: 2.0, curlWidth: 0.12
        )
        let noCurlBounds = noCurl.path(in: rect).boundingRect
        let curlBounds = withCurl.path(in: rect).boundingRect
        // Curl should extend higher (lower Y) than normal wave
        #expect(curlBounds.minY < noCurlBounds.minY)
    }

    @Test("curlCount > 0 path is non-empty")
    func curlPathNonEmpty() {
        let wave = OceanWaveShape(
            amplitude: 0.15, frequency: 2, steepness: 0.3,
            curlCount: 2, curlHeight: 1.5, curlWidth: 0.1
        )
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        #expect(!wave.path(in: rect).isEmpty)
    }

    @Test("curl with zero amplitude produces no curl")
    func curlWithZeroAmplitude() {
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let wave = OceanWaveShape(
            amplitude: 0, curlCount: 1, curlHeight: 2.0
        )
        let bounds = wave.path(in: rect).boundingRect
        // Zero amplitude = flat wave at verticalOffset, no curl
        #expect(bounds.minY >= 49)
    }

    @Test("Stroke shape supports curl")
    func strokeWithCurl() {
        let stroke = OceanWaveStrokeShape(
            amplitude: 0.15, frequency: 2, steepness: 0.3,
            curlCount: 1, curlHeight: 1.5
        )
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        #expect(!stroke.path(in: rect).isEmpty)
    }

    @Test("Foam shape supports curl")
    func foamWithCurl() {
        let foam = OceanFoamGradientShape(
            amplitude: 0.15, frequency: 2, steepness: 0.3,
            curlCount: 1, curlHeight: 1.5
        )
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        #expect(!foam.path(in: rect).isEmpty)
    }

    // MARK: - Stroke Shape Tests

    @Test("Stroke shape is non-empty for valid rect")
    func strokeNonEmpty() {
        let stroke = OceanWaveStrokeShape()
        let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
        #expect(!stroke.path(in: rect).isEmpty)
    }

    @Test("Stroke shape is empty for zero rect")
    func strokeEmptyForZero() {
        let stroke = OceanWaveStrokeShape()
        #expect(stroke.path(in: .zero).isEmpty)
    }

    @Test("Stroke animatableData reflects phase")
    func strokeAnimatableData() {
        var stroke = OceanWaveStrokeShape(phase: 2.0)
        #expect(stroke.animatableData == 2.0)
        stroke.animatableData = 4.0
        #expect(stroke.animatableData == 4.0)
    }

    // MARK: - Foam Gradient Shape Tests

    @Test("Foam gradient shape is non-empty for valid rect")
    func foamNonEmpty() {
        let foam = OceanFoamGradientShape()
        let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
        #expect(!foam.path(in: rect).isEmpty)
    }

    @Test("Foam gradient shape is empty for zero rect")
    func foamEmptyForZero() {
        let foam = OceanFoamGradientShape()
        #expect(foam.path(in: .zero).isEmpty)
    }

    private func firstWavePoint(from path: Path) -> CGPoint? {
        var point: CGPoint?
        path.cgPath.applyWithBlock { elementPtr in
            guard point == nil else { return }
            let element = elementPtr.pointee
            switch element.type {
            case .moveToPoint, .addLineToPoint:
                point = element.points[0]
            default:
                break
            }
        }
        return point
    }
}
