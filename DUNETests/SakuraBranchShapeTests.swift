import Foundation
import SwiftUI
import Testing
@testable import DUNE

@Suite("SakuraBranchShape Geometry")
struct SakuraBranchShapeTests {
    @Test("Path is non-empty for valid rect")
    func pathNonEmpty() {
        let shape = SakuraBranchShape()
        let rect = CGRect(x: 0, y: 0, width: 280, height: 140)
        #expect(!shape.path(in: rect).isEmpty)
    }

    @Test("Path is empty for zero-size rect")
    func pathEmptyForZeroRect() {
        let shape = SakuraBranchShape()
        #expect(shape.path(in: .zero).isEmpty)
        #expect(shape.path(in: CGRect(x: 0, y: 0, width: 0, height: 100)).isEmpty)
        #expect(shape.path(in: CGRect(x: 0, y: 0, width: 200, height: 0)).isEmpty)
    }

    @Test("animatableData reflects phase")
    func animatableData() {
        var shape = SakuraBranchShape(phase: 1.1)
        #expect(shape.animatableData == 1.1)
        shape.animatableData = 2.2
        #expect(shape.animatableData == 2.2)
    }

    @Test("Twig density affects branch extent")
    func twigDensityChangesBounds() {
        let rect = CGRect(x: 0, y: 0, width: 320, height: 180)
        let sparse = SakuraBranchShape(amplitude: 0.1, frequency: 1.2, phase: 0, verticalOffset: 0.7, twigDensity: 0.1)
        let dense = SakuraBranchShape(amplitude: 0.1, frequency: 1.2, phase: 0, verticalOffset: 0.7, twigDensity: 0.8)

        let sparseBounds = sparse.path(in: rect).boundingRect
        let denseBounds = dense.path(in: rect).boundingRect

        #expect(denseBounds.minY < sparseBounds.minY || denseBounds.maxX != sparseBounds.maxX)
    }
}
