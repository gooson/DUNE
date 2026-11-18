import Foundation
import SwiftUI
import Testing
import UIKit
@testable import DUNE

@Suite("ForestSilhouetteShape Geometry")
struct ForestSilhouetteShapeTests {
    @Test("Path is non-empty for valid rect")
    func pathNonEmpty() {
        let forest = ForestSilhouetteShape()
        let rect = CGRect(x: 0, y: 0, width: 240, height: 140)
        #expect(!forest.path(in: rect).isEmpty)
    }

    @Test("Path is empty for zero-size rect")
    func pathEmptyForZeroRect() {
        let forest = ForestSilhouetteShape()
        #expect(forest.path(in: .zero).isEmpty)
        #expect(forest.path(in: CGRect(x: 0, y: 0, width: 0, height: 120)).isEmpty)
        #expect(forest.path(in: CGRect(x: 0, y: 0, width: 120, height: 0)).isEmpty)
    }

    @Test("animatableData reflects phase")
    func animatableData() {
        var forest = ForestSilhouetteShape(phase: 0.8)
        #expect(forest.animatableData == 0.8)
        forest.animatableData = 1.6
        #expect(forest.animatableData == 1.6)
    }

    @Test("Tree density shifts silhouette upward (conifer peaks)")
    func treeDensityProminence() {
        let rect = CGRect(x: 0, y: 0, width: 320, height: 180)
        let hillsOnly = ForestSilhouetteShape(
            amplitude: 0.2,
            frequency: 0.8,
            treeDensity: 0
        )
        let coniferForest = ForestSilhouetteShape(
            amplitude: 0.2,
            frequency: 0.8,
            treeDensity: 0.8
        )

        let hillsBounds = hillsOnly.path(in: rect).boundingRect
        let forestBounds = coniferForest.path(in: rect).boundingRect

        // High treeDensity creates taller peaks → lower minY
        #expect(forestBounds.minY < hillsBounds.minY)
    }

    @Test("Path stays within reasonable bounds with high amplitude and density")
    func pathWithinBoundsHighAmplitude() {
        let shape = ForestSilhouetteShape(
            amplitude: 0.45, frequency: 0.5, phase: 0, verticalOffset: 0.4, treeDensity: 0.85
        )
        let rect = CGRect(x: 0, y: 0, width: 400, height: 340)
        let bounds = shape.path(in: rect).boundingRect

        // X should stay within rect
        #expect(bounds.minX >= rect.minX - 2)
        #expect(bounds.maxX <= rect.maxX + 2)
        // Bottom closes to rect.height
        #expect(bounds.maxY <= rect.maxY + 2)
    }

    @Test("Different phases produce different paths")
    func phaseChangesPath() {
        let rect = CGRect(x: 0, y: 0, width: 300, height: 250)
        let shape0 = ForestSilhouetteShape(
            amplitude: 0.3, frequency: 0.6, phase: 0, verticalOffset: 0.4, treeDensity: 0.7
        )
        let shapeHalfPi = ForestSilhouetteShape(
            amplitude: 0.3, frequency: 0.6, phase: .pi, verticalOffset: 0.4, treeDensity: 0.7
        )

        let path0 = shape0.path(in: rect)
        let pathPi = shapeHalfPi.path(in: rect)

        // Bezier paths with different phases must differ structurally
        var points0 = [CGPoint]()
        path0.cgPath.applyWithBlock { element in
            let pt = element.pointee.points[0]
            points0.append(pt)
        }
        var pointsPi = [CGPoint]()
        pathPi.cgPath.applyWithBlock { element in
            let pt = element.pointee.points[0]
            pointsPi.append(pt)
        }
        // First point Y should differ due to phase shift
        guard let first0 = points0.first, let firstPi = pointsPi.first else {
            Issue.record("No path points found")
            return
        }
        #expect(abs(first0.y - firstPi.y) > 0.1)
    }

    @Test("Zero amplitude produces flat wave")
    func zeroAmplitude() {
        let shape = ForestSilhouetteShape(
            amplitude: 0, frequency: 0.6, phase: 0, verticalOffset: 0.5, treeDensity: 0.7
        )
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let bounds = shape.path(in: rect).boundingRect

        // With zero amplitude, ridge line is approximately flat at verticalOffset (0.5 * 200 = 100).
        // Edge noise + treeModulation can shift ±3pt.
        #expect(bounds.minY >= 95 && bounds.minY <= 105)
    }
}

@Suite("Forest Canopy woodcut playback")
struct ForestCanopyMotionTests {
    @Test("Foreground clears before the valley and both fill again at the seam")
    func fogCycle() {
        let dense = ForestCanopyMotion.frame(at: 0)
        let clearing = ForestCanopyMotion.frame(at: ForestCanopyMotion.staticElapsed)
        let clear = ForestCanopyMotion.frame(at: 16)
        let refilling = ForestCanopyMotion.frame(at: 21)
        let loop = ForestCanopyMotion.frame(at: ForestCanopyMotion.period)
        #expect(ForestCanopyMotion.period == 24)
        #expect(dense.frontFog.opacity > 0.9 && dense.valleyFog.opacity > 0.9)
        #expect(clearing.frontFog.opacity < clearing.valleyFog.opacity)
        #expect(clear.frontFog.opacity < 0.05 && clear.valleyFog.opacity < 0.15)
        #expect(refilling.valleyFog.opacity > clear.valleyFog.opacity)
        #expect(loop.frontFog.opacity == dense.frontFog.opacity)
        #expect(loop.valleyFog.opacity == dense.valleyFog.opacity)
    }

    @Test("Needle tips have independent short travel in print coordinates")
    func needleTravel() {
        let upperPeak = ForestCanopyMotion.frame(at: 7.8 * 0.42 - 1.4)
        let lowerPeak = ForestCanopyMotion.frame(at: 9.6 * 0.42 - 2.6)
        #expect(abs(upperPeak.upperNeedles.y + 0.0074) < 0.00001)
        #expect(abs(lowerPeak.lowerNeedles.y + 0.0105) < 0.00001)
        #expect(upperPeak.lowerNeedles.y > lowerPeak.lowerNeedles.y)
        #expect(lowerPeak.upperNeedles.y > upperPeak.upperNeedles.y)
    }

    @Test("Motion runs only for active scenes with motion and power budget")
    func playbackPolicy() {
        #expect(ForestCanopyMotion.shouldAnimate(scenePhase: .active, reduceMotion: false, isLowPowerModeEnabled: false))
        #expect(!ForestCanopyMotion.shouldAnimate(scenePhase: .inactive, reduceMotion: false, isLowPowerModeEnabled: false))
        #expect(!ForestCanopyMotion.shouldAnimate(scenePhase: .background, reduceMotion: false, isLowPowerModeEnabled: false))
        #expect(!ForestCanopyMotion.shouldAnimate(scenePhase: .active, reduceMotion: true, isLowPowerModeEnabled: false))
        #expect(!ForestCanopyMotion.shouldAnimate(scenePhase: .active, reduceMotion: false, isLowPowerModeEnabled: true))
    }

    @Test("Both tip masks map to the print and the fog asset carries alpha")
    func bundledArt() throws {
        let print = try #require(UIImage(named: "ForestCanopyPrint")?.cgImage)
        for name in ["ForestCanopyUpperTips", "ForestCanopyLowerTips"] {
            let layer = try #require(UIImage(named: name)?.cgImage)
            #expect(layer.width == print.width && layer.height == print.height)
            #expect(layer.alphaInfo != .none && layer.alphaInfo != .noneSkipLast && layer.alphaInfo != .noneSkipFirst)
        }
        let fog = try #require(UIImage(named: "ForestValleyFog")?.cgImage)
        #expect(fog.width > 0 && fog.height > 0)
        #expect(fog.alphaInfo != .none && fog.alphaInfo != .noneSkipLast && fog.alphaInfo != .noneSkipFirst)
    }
}
