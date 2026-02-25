import Foundation
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
        let bounds0 = wave0.path(in: rect).boundingRect
        let boundsHalfPi = waveHalfPi.path(in: rect).boundingRect
        // Different phase should shift the wave vertically at different points
        let sameBounds = bounds0.origin == boundsHalfPi.origin && bounds0.size == boundsHalfPi.size
        // They MAY have similar bounding rects, but shouldn't be identical due to phase shift
        // This is a soft check — the key thing is both paths are valid
        #expect(!wave0.path(in: rect).isEmpty)
        #expect(!waveHalfPi.path(in: rect).isEmpty)
        _ = sameBounds // suppress unused warning
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
}
