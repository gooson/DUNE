import Foundation
import SwiftUI
import Testing
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

    @Test("Ruggedness increases path irregularity")
    func ruggednessEffect() {
        let rect = CGRect(x: 0, y: 0, width: 320, height: 180)
        let smooth = ForestSilhouetteShape(
            amplitude: 0.1,
            frequency: 0.8,
            ruggedness: 0
        )
        let rugged = ForestSilhouetteShape(
            amplitude: 0.1,
            frequency: 0.8,
            ruggedness: 0.8
        )

        let smoothBounds = smooth.path(in: rect).boundingRect
        let ruggedBounds = rugged.path(in: rect).boundingRect

        // Rugged path should have different vertical extent
        #expect(smoothBounds.height != ruggedBounds.height)
    }

    @Test("Tree density adds canopy silhouette")
    func treeDensityEffect() {
        let rect = CGRect(x: 0, y: 0, width: 320, height: 180)
        let noTrees = ForestSilhouetteShape(
            amplitude: 0.2,
            frequency: 0.8,
            treeDensity: 0
        )
        let withTrees = ForestSilhouetteShape(
            amplitude: 0.2,
            frequency: 0.8,
            treeDensity: 0.8
        )

        let noTreesBounds = noTrees.path(in: rect).boundingRect
        let treesBounds = withTrees.path(in: rect).boundingRect

        // Tree density creates taller peaks → lower minY
        #expect(treesBounds.minY < noTreesBounds.minY)
    }

    @Test("Path stays within reasonable bounds")
    func pathWithinBounds() {
        let shape = ForestSilhouetteShape(
            amplitude: 0.15, frequency: 1.0, phase: 0,
            verticalOffset: 0.4, ruggedness: 0.3, treeDensity: 0.2
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
            amplitude: 0.1, frequency: 0.6, phase: 0,
            verticalOffset: 0.4, ruggedness: 0.2, treeDensity: 0.1
        )
        let shapePi = ForestSilhouetteShape(
            amplitude: 0.1, frequency: 0.6, phase: .pi,
            verticalOffset: 0.4, ruggedness: 0.2, treeDensity: 0.1
        )

        let path0 = shape0.path(in: rect)
        let pathPi = shapePi.path(in: rect)

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
        guard let first0 = points0.first, let firstPi = pointsPi.first else {
            Issue.record("No path points found")
            return
        }
        #expect(abs(first0.y - firstPi.y) > 0.1)
    }

    @Test("Zero amplitude produces flat wave")
    func zeroAmplitude() {
        let shape = ForestSilhouetteShape(
            amplitude: 0, frequency: 0.6, phase: 0,
            verticalOffset: 0.5, ruggedness: 0.2, treeDensity: 0.1
        )
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let bounds = shape.path(in: rect).boundingRect

        // With zero amplitude, ridge line is near verticalOffset (0.5 * 200 = 100)
        // Edge noise adds ±2.1 of variation
        #expect(bounds.minY >= 90 && bounds.minY <= 110)
    }
}
