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

    @Test("Tree density increases canopy prominence")
    func treeDensityProminence() {
        let rect = CGRect(x: 0, y: 0, width: 320, height: 180)
        let sparse = ForestSilhouetteShape(
            amplitude: 0.1,
            frequency: 1.0,
            treeDensity: 0
        )
        let dense = ForestSilhouetteShape(
            amplitude: 0.1,
            frequency: 1.0,
            treeDensity: 0.4
        )

        let sparseBounds = sparse.path(in: rect).boundingRect
        let denseBounds = dense.path(in: rect).boundingRect

        #expect(denseBounds.minY < sparseBounds.minY)
    }

    @Test("Path stays within reasonable bounds with high amplitude")
    func pathWithinBoundsHighAmplitude() {
        let shape = ForestSilhouetteShape(
            amplitude: 0.4, frequency: 0.95, phase: 0, verticalOffset: 0.5, treeDensity: 0.55
        )
        let rect = CGRect(x: 0, y: 0, width: 400, height: 280)
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
            amplitude: 0.3, frequency: 1.5, phase: 0, verticalOffset: 0.5, treeDensity: 0.3
        )
        let shapeHalfPi = ForestSilhouetteShape(
            amplitude: 0.3, frequency: 1.5, phase: .pi, verticalOffset: 0.5, treeDensity: 0.3
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
            amplitude: 0, frequency: 0.75, phase: 0, verticalOffset: 0.5, treeDensity: 0.5
        )
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let bounds = shape.path(in: rect).boundingRect

        // With zero amplitude, ridge line is flat at verticalOffset (0.5 * 200 = 100)
        #expect(bounds.minY >= 98 && bounds.minY <= 102)
    }
}
