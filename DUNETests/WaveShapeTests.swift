import Foundation
import SwiftUI
import Testing
@testable import DUNE

@Suite("WaveShape Geometry")
struct WaveShapeTests {
    @Test("Path is non-empty for valid rect")
    func pathNonEmpty() {
        let wave = WaveShape(amplitude: 0.03, frequency: 2, phase: 0, verticalOffset: 0.7)
        let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
        let path = wave.path(in: rect)
        #expect(!path.isEmpty)
    }

    @Test("Path is empty for zero-size rect")
    func pathEmptyForZeroRect() {
        let wave = WaveShape()
        let empty = wave.path(in: .zero)
        #expect(empty.isEmpty)

        let zeroWidth = wave.path(in: CGRect(x: 0, y: 0, width: 0, height: 100))
        #expect(zeroWidth.isEmpty)

        let zeroHeight = wave.path(in: CGRect(x: 0, y: 0, width: 100, height: 0))
        #expect(zeroHeight.isEmpty)
    }

    @Test("Path stays within rect bounds")
    func pathWithinBounds() {
        let wave = WaveShape(amplitude: 0.5, frequency: 3, phase: 0, verticalOffset: 0.5)
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let path = wave.path(in: rect)
        let bounds = path.boundingRect
        #expect(bounds.minX >= rect.minX - 1)
        #expect(bounds.maxX <= rect.maxX + 1)
        #expect(bounds.minY >= rect.minY - 1)
        #expect(bounds.maxY <= rect.maxY + 1)
    }

    @Test("Different phases produce different paths")
    func phaseChangesPath() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
        let wave0 = WaveShape(amplitude: 0.1, frequency: 2, phase: 0, verticalOffset: 0.5)
        let waveHalfPi = WaveShape(amplitude: 0.1, frequency: 2, phase: .pi / 2, verticalOffset: 0.5)
        let path0 = wave0.path(in: rect)
        let pathHalfPi = waveHalfPi.path(in: rect)
        let start0 = firstWavePoint(from: path0)
        let startHalfPi = firstWavePoint(from: pathHalfPi)

        #expect(start0 != nil)
        #expect(startHalfPi != nil)
        if let start0, let startHalfPi {
            // Both paths start at x=0; phase shift should move y significantly.
            #expect(abs(start0.x - startHalfPi.x) < 0.001)
            #expect(abs(start0.y - startHalfPi.y) > 0.1)
        }
    }

    @Test("Zero amplitude produces flat wave")
    func zeroAmplitude() {
        let wave = WaveShape(amplitude: 0, frequency: 2, phase: 0, verticalOffset: 0.5)
        let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
        let bounds = wave.path(in: rect).boundingRect
        // With zero amplitude, wave line is flat at verticalOffset (0.5 * 100 = 50)
        // Bounding rect top should be at y=50 (the wave line), bottom at y=100 (fill to bottom)
        #expect(bounds.minY >= 49 && bounds.minY <= 51)
    }

    @Test("animatableData reflects phase")
    func animatableData() {
        var wave = WaveShape(amplitude: 0.03, frequency: 2, phase: 1.5, verticalOffset: 0.7)
        #expect(wave.animatableData == 1.5)
        wave.animatableData = 3.0
        #expect(wave.animatableData == 3.0)
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
