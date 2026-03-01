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
            ruggedness: 0.1,
            treeDensity: 0
        )
        let dense = ForestSilhouetteShape(
            amplitude: 0.1,
            frequency: 1.0,
            ruggedness: 0.1,
            treeDensity: 0.4
        )

        let sparseBounds = sparse.path(in: rect).boundingRect
        let denseBounds = dense.path(in: rect).boundingRect

        #expect(denseBounds.minY < sparseBounds.minY)
    }

    @Test("Ruggedness changes silhouette profile")
    func ruggednessChangesProfile() {
        let rect = CGRect(x: 0, y: 0, width: 320, height: 180)
        let smooth = ForestSilhouetteShape(amplitude: 0.1, frequency: 1.2, ruggedness: 0.0, treeDensity: 0.08)
        let rugged = ForestSilhouetteShape(amplitude: 0.1, frequency: 1.2, ruggedness: 0.6, treeDensity: 0.08)

        let smoothBounds = smooth.path(in: rect).boundingRect
        let ruggedBounds = rugged.path(in: rect).boundingRect

        #expect(smoothBounds.height != ruggedBounds.height)
    }
}

