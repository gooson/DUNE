import Foundation
import SwiftUI
import Testing
@testable import DUNE

@Suite("SakuraPetalShape Geometry")
struct SakuraPetalShapeTests {
    @Test("Path is non-empty for valid rect")
    func pathNonEmpty() {
        let shape = SakuraPetalShape()
        let rect = CGRect(x: 0, y: 0, width: 240, height: 140)
        #expect(!shape.path(in: rect).isEmpty)
    }

    @Test("Path is empty for zero-size rect")
    func pathEmptyForZeroRect() {
        let shape = SakuraPetalShape()
        #expect(shape.path(in: .zero).isEmpty)
        #expect(shape.path(in: CGRect(x: 0, y: 0, width: 0, height: 140)).isEmpty)
        #expect(shape.path(in: CGRect(x: 0, y: 0, width: 240, height: 0)).isEmpty)
    }

    @Test("animatableData reflects phase")
    func animatableData() {
        var shape = SakuraPetalShape(phase: 0.9)
        #expect(shape.animatableData == 0.9)
        shape.animatableData = 1.8
        #expect(shape.animatableData == 1.8)
    }

    @Test("Petal density increases crest prominence")
    func petalDensityChangesProfile() {
        let rect = CGRect(x: 0, y: 0, width: 320, height: 180)
        let flat = SakuraPetalShape(
            amplitude: 0.2,
            frequency: 1.1,
            petalDensity: 0
        )
        let petal = SakuraPetalShape(
            amplitude: 0.2,
            frequency: 1.1,
            petalDensity: 0.8
        )

        let flatBounds = flat.path(in: rect).boundingRect
        let petalBounds = petal.path(in: rect).boundingRect

        // Higher petal density should push some crests upward (smaller minY).
        #expect(petalBounds.minY < flatBounds.minY)
    }

    @Test("Different phases produce different ridge geometry")
    func phaseChangesPath() {
        let rect = CGRect(x: 0, y: 0, width: 320, height: 180)
        let phase0 = SakuraPetalShape(amplitude: 0.2, frequency: 1.2, phase: 0, petalDensity: 0.8)
        let phasePi = SakuraPetalShape(amplitude: 0.2, frequency: 1.2, phase: .pi, petalDensity: 0.8)

        let bounds0 = phase0.path(in: rect).boundingRect
        let boundsPi = phasePi.path(in: rect).boundingRect
        #expect(abs(bounds0.minY - boundsPi.minY) > 0.05 || abs(bounds0.maxY - boundsPi.maxY) > 0.05)
    }
}
