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

@Suite("ArcticRibbonShape Geometry")
struct ArcticRibbonShapeTests {
    @Test("Path is non-empty for valid rect")
    func pathNonEmpty() {
        let shape = ArcticRibbonShape()
        let rect = CGRect(x: 0, y: 0, width: 240, height: 140)
        #expect(!shape.path(in: rect).isEmpty)
    }

    @Test("Path is empty for zero-size rect")
    func pathEmptyForZeroRect() {
        let shape = ArcticRibbonShape()
        #expect(shape.path(in: .zero).isEmpty)
        #expect(shape.path(in: CGRect(x: 0, y: 0, width: 0, height: 120)).isEmpty)
        #expect(shape.path(in: CGRect(x: 0, y: 0, width: 120, height: 0)).isEmpty)
    }

    @Test("animatableData reflects phase")
    func animatableData() {
        var shape = ArcticRibbonShape(phase: 1.2)
        #expect(shape.animatableData == 1.2)
        shape.animatableData = 2.4
        #expect(shape.animatableData == 2.4)
    }

    @Test("Different phases produce different paths")
    func phaseChangesPath() {
        let rect = CGRect(x: 0, y: 0, width: 300, height: 180)
        let shape0 = ArcticRibbonShape(amplitude: 0.08, frequency: 1.9, phase: 0, verticalOffset: 0.52, ridge: 0.24)
        let shapePi = ArcticRibbonShape(
            amplitude: 0.08,
            frequency: 1.9,
            phase: .pi,
            verticalOffset: 0.52,
            ridge: 0.24
        )
        let bounds0 = shape0.path(in: rect).boundingRect
        let boundsPi = shapePi.path(in: rect).boundingRect
        #expect(abs(bounds0.minY - boundsPi.minY) > 0.1 || abs(bounds0.maxY - boundsPi.maxY) > 0.1)
    }
}

@Suite("Arctic Aurora LOD")
struct ArcticAuroraLODTests {
    @Test("Quality mode is conserve when low power mode is enabled")
    func lowPowerForcesConserve() {
        let mode = ArcticAuroraLOD.qualityMode(
            isLowPowerModeEnabled: true,
            reduceMotion: false
        )
        #expect(mode == .conserve)
    }

    @Test("Quality mode is conserve when reduce motion is enabled")
    func reduceMotionForcesConserve() {
        let mode = ArcticAuroraLOD.qualityMode(
            isLowPowerModeEnabled: false,
            reduceMotion: true
        )
        #expect(mode == .conserve)
    }

    @Test("Quality mode is normal when low power and reduce motion are both off")
    func defaultsToNormal() {
        let mode = ArcticAuroraLOD.qualityMode(
            isLowPowerModeEnabled: false,
            reduceMotion: false
        )
        #expect(mode == .normal)
    }

    @Test("Scaled count preserves base in normal mode")
    func scaledCountNormal() {
        let scaled = ArcticAuroraLOD.scaledCount(
            baseCount: 11,
            mode: .normal,
            conserveScale: 0.5
        )
        #expect(scaled == 11)
    }

    @Test("Scaled count reduces repeats in conserve mode with minimum bound")
    func scaledCountConserveBounded() {
        let scaled = ArcticAuroraLOD.scaledCount(
            baseCount: 5,
            mode: .conserve,
            conserveScale: 0.2,
            minimum: 2
        )
        #expect(scaled == 2)
    }

    @Test("Scaled count returns zero when base is zero")
    func scaledCountZeroBase() {
        let scaled = ArcticAuroraLOD.scaledCount(
            baseCount: 0,
            mode: .conserve,
            conserveScale: 0.5
        )
        #expect(scaled == 0)
    }
}

@Suite("SolarFlareShape Geometry")
struct SolarFlareShapeTests {
    @Test("Path is non-empty for valid rect")
    func pathNonEmpty() {
        let shape = SolarFlareShape()
        let rect = CGRect(x: 0, y: 0, width: 240, height: 140)
        #expect(!shape.path(in: rect).isEmpty)
    }

    @Test("Path is empty for zero-size rect")
    func pathEmptyForZeroRect() {
        let shape = SolarFlareShape()
        #expect(shape.path(in: .zero).isEmpty)
        #expect(shape.path(in: CGRect(x: 0, y: 0, width: 0, height: 120)).isEmpty)
        #expect(shape.path(in: CGRect(x: 0, y: 0, width: 120, height: 0)).isEmpty)
    }

    @Test("animatableData reflects phase")
    func animatableData() {
        var shape = SolarFlareShape(phase: 1.4)
        #expect(shape.animatableData == 1.4)
        shape.animatableData = 2.8
        #expect(shape.animatableData == 2.8)
    }

    @Test("Different phases produce different paths")
    func phaseChangesPath() {
        let rect = CGRect(x: 0, y: 0, width: 300, height: 180)
        let shape0 = SolarFlareShape(amplitude: 0.08, frequency: 2.0, phase: 0, verticalOffset: 0.54, pulse: 0.24)
        let shapePi = SolarFlareShape(
            amplitude: 0.08,
            frequency: 2.0,
            phase: .pi,
            verticalOffset: 0.54,
            pulse: 0.24
        )
        let bounds0 = shape0.path(in: rect).boundingRect
        let boundsPi = shapePi.path(in: rect).boundingRect
        #expect(abs(bounds0.minY - boundsPi.minY) > 0.1 || abs(bounds0.maxY - boundsPi.maxY) > 0.1)
    }
}
