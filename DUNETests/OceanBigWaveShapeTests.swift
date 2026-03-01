import Foundation
import SwiftUI
import Testing
@testable import DUNE

@Suite("OceanBigWaveShape Geometry")
struct OceanBigWaveShapeTests {
    @Test("Path is non-empty for valid rect")
    func pathNonEmpty() {
        let wave = OceanBigWaveShape()
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        #expect(!wave.path(in: rect).isEmpty)
    }

    @Test("Path is empty for zero-size rect")
    func pathEmptyForZeroRect() {
        let wave = OceanBigWaveShape()
        #expect(wave.path(in: .zero).isEmpty)
        #expect(wave.path(in: CGRect(x: 0, y: 0, width: 0, height: 200)).isEmpty)
        #expect(wave.path(in: CGRect(x: 0, y: 0, width: 300, height: 0)).isEmpty)
    }

    @Test("animatableData reflects phase")
    func animatableData() {
        var wave = OceanBigWaveShape(phase: 1.5)
        #expect(wave.animatableData == 1.5)
        wave.animatableData = 3.0
        #expect(wave.animatableData == 3.0)
    }

    @Test("Different phases produce different paths")
    func phaseChangesPath() {
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let wave0 = OceanBigWaveShape(phase: 0)
        let wavePi = OceanBigWaveShape(phase: .pi / 2)
        let bounds0 = wave0.path(in: rect).boundingRect
        let boundsPi = wavePi.path(in: rect).boundingRect
        // Phase shifts the wave horizontally via sway
        #expect(bounds0 != boundsPi)
    }

    @Test("Mirror produces horizontally flipped path")
    func mirrorFlips() {
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let normal = OceanBigWaveShape(mirror: false)
        let mirrored = OceanBigWaveShape(mirror: true)
        let normalBounds = normal.path(in: rect).boundingRect
        let mirroredBounds = mirrored.path(in: rect).boundingRect
        // Mirrored wave should have its peak on the opposite side
        let normalCenterX = normalBounds.midX
        let mirroredCenterX = mirroredBounds.midX
        #expect(abs(normalCenterX - mirroredCenterX) > 1)
    }

    @Test("Path stays within reasonable bounds")
    func pathBounds() {
        let wave = OceanBigWaveShape()
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let bounds = wave.path(in: rect).boundingRect
        // Wave should not extend more than sway amount beyond rect
        let maxSway: CGFloat = 300 * 0.01 + 1  // w * 0.01 + tolerance
        #expect(bounds.minX >= rect.minX - maxSway)
        #expect(bounds.maxX <= rect.maxX + maxSway)
        #expect(bounds.minY >= rect.minY - 1)
        #expect(bounds.maxY <= rect.maxY + 1)
    }

    // MARK: - Crest Shape Tests

    @Test("Crest shape is non-empty for valid rect")
    func crestNonEmpty() {
        let crest = OceanBigWaveCrestShape()
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        #expect(!crest.path(in: rect).isEmpty)
    }

    @Test("Crest shape is empty for zero rect")
    func crestEmptyForZero() {
        let crest = OceanBigWaveCrestShape()
        #expect(crest.path(in: .zero).isEmpty)
    }

    @Test("Crest animatableData reflects phase")
    func crestAnimatableData() {
        var crest = OceanBigWaveCrestShape(phase: 2.0)
        #expect(crest.animatableData == 2.0)
        crest.animatableData = 4.0
        #expect(crest.animatableData == 4.0)
    }
}
