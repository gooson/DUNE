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
