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

    @Test("Scaled count respects normal scale override")
    func scaledCountNormalScaleOverride() {
        let scaled = ArcticAuroraLOD.scaledCount(
            baseCount: 10,
            mode: .normal,
            normalScale: 0.6,
            conserveScale: 0.5
        )
        #expect(scaled == 6)
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

@Suite("ArcticAnimationPhase")
struct ArcticAnimationPhaseTests {
    @Test("Phase is zero when duration is zero")
    func zeroDuration() {
        let result = ArcticAnimationPhase.phase(elapsed: 10, duration: 0)
        #expect(result == 0)
    }

    @Test("Phase is zero at elapsed zero")
    func elapsedZero() {
        let result = ArcticAnimationPhase.phase(elapsed: 0, duration: 14)
        #expect(result == 0)
    }

    @Test("Phase completes full cycle at duration boundary")
    func fullCycle() {
        let duration = 14.0
        // At elapsed == duration, truncatingRemainder wraps to 0
        let atBoundary = ArcticAnimationPhase.phase(elapsed: duration, duration: duration)
        #expect(abs(atBoundary) < 0.001)
    }

    @Test("Phase at half duration is approximately pi")
    func halfCycle() {
        let duration = 18.0
        let result = ArcticAnimationPhase.phase(elapsed: duration / 2, duration: duration)
        #expect(abs(result - .pi) < 0.001)
    }

    @Test("Reverse produces negative phase")
    func reverseDirection() {
        let result = ArcticAnimationPhase.phase(elapsed: 5, duration: 20, reverse: true)
        #expect(result < 0)
        let forward = ArcticAnimationPhase.phase(elapsed: 5, duration: 20, reverse: false)
        #expect(abs(result + forward) < 0.001)
    }

    @Test("Phase stays within [0, 2π) for forward direction")
    func phaseRange() {
        for elapsed in stride(from: 0.0, through: 100.0, by: 3.7) {
            let p = ArcticAnimationPhase.phase(elapsed: elapsed, duration: 14)
            #expect(p >= 0)
            #expect(p < 2 * .pi + 0.001)
        }
    }
}

@Suite("ArcticPerformanceProfile")
struct ArcticPerformanceProfileTests {
    @Test("Profiles get more aggressive as surfaces shrink")
    func surfaceOrdering() {
        let tab = ArcticPerformanceProfile.profile(for: .tab)
        let detail = ArcticPerformanceProfile.profile(for: .detail)
        let sheet = ArcticPerformanceProfile.profile(for: .sheet)

        #expect(tab.microPhaseStep < detail.microPhaseStep)
        #expect(detail.microPhaseStep < sheet.microPhaseStep)
        #expect(tab.edgePhaseStep < detail.edgePhaseStep)
        #expect(detail.edgePhaseStep < sheet.edgePhaseStep)

        #expect(tab.filamentNormalScale > detail.filamentNormalScale)
        #expect(detail.filamentNormalScale > sheet.filamentNormalScale)
        #expect(tab.microSparkleNormalScale > detail.microSparkleNormalScale)
        #expect(detail.microSparkleNormalScale > sheet.microSparkleNormalScale)
    }
}

@Suite("ArcticPhaseQuantizer")
struct ArcticPhaseQuantizerTests {
    @Test("Non-positive step preserves elapsed time")
    func nonPositiveStep() {
        #expect(ArcticPhaseQuantizer.quantizedElapsed(12.34, step: 0) == 12.34)
        #expect(ArcticPhaseQuantizer.quantizedElapsed(12.34, step: -1) == 12.34)
    }

    @Test("Elapsed snaps down to nearest phase step")
    func quantizesDown() {
        let step = 1.0 / 30.0
        let elapsed = 1.09
        let quantized = ArcticPhaseQuantizer.quantizedElapsed(elapsed, step: step)

        #expect(quantized <= elapsed)
        #expect(elapsed - quantized < step + 0.000_001)
    }

    @Test("Elapsed already on boundary stays unchanged")
    func boundaryPreserved() {
        let step = 0.05
        let elapsed = 1.25
        #expect(abs(ArcticPhaseQuantizer.quantizedElapsed(elapsed, step: step) - elapsed) < 0.000_001)
    }
}

@Suite("ArcticPlaybackPolicy")
struct ArcticPlaybackPolicyTests {
    @Test("Playback pauses when reduce motion is enabled")
    func reduceMotionPauses() {
        #expect(ArcticPlaybackPolicy.isPaused(scenePhase: .active, reduceMotion: true))
    }

    @Test("Playback pauses when scene is inactive")
    func inactiveScenePauses() {
        #expect(ArcticPlaybackPolicy.isPaused(scenePhase: .inactive, reduceMotion: false))
    }

    @Test("Playback pauses when scene is backgrounded")
    func backgroundScenePauses() {
        #expect(ArcticPlaybackPolicy.isPaused(scenePhase: .background, reduceMotion: false))
    }

    @Test("Playback stays active only for active scene without reduce motion")
    func activeSceneContinues() {
        #expect(!ArcticPlaybackPolicy.isPaused(scenePhase: .active, reduceMotion: false))
    }
}

@Suite("ArcticNormalizedSamples")
struct ArcticNormalizedSamplesTests {
    @Test("Known caches return inclusive sample counts")
    func inclusiveCounts() {
        #expect(ArcticNormalizedSamples.ribbon.count == 121)
        #expect(ArcticNormalizedSamples.curtain.count == 89)
        #expect(ArcticNormalizedSamples.edgeGlow.count == 85)
    }

    @Test("Fallback count zero returns origin sample")
    func zeroFallback() {
        #expect(ArcticNormalizedSamples.values(count: 0) == [0])
    }

    @Test("Samples are normalized from zero to one")
    func normalizedRange() {
        let samples = ArcticNormalizedSamples.values(count: 8)
        #expect(samples.first == 0)
        #expect(samples.last == 1)
        #expect(samples.count == 9)

        for idx in 1..<samples.count {
            #expect(samples[idx] > samples[idx - 1])
        }
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
