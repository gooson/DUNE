import Foundation
import SwiftUI
import Testing
@testable import DUNE

@Suite("OceanArcPattern Geometry")
struct OceanArcPatternTests {
    @Test("Path is non-empty for valid rect")
    func pathNonEmpty() {
        let pattern = OceanArcPattern()
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let path = pattern.path(in: rect)
        #expect(!path.isEmpty)
    }

    @Test("Path is empty for zero-size rect")
    func pathEmptyForZeroRect() {
        let pattern = OceanArcPattern()
        #expect(pattern.path(in: .zero).isEmpty)
        #expect(pattern.path(in: CGRect(x: 0, y: 0, width: 0, height: 100)).isEmpty)
        #expect(pattern.path(in: CGRect(x: 0, y: 0, width: 100, height: 0)).isEmpty)
    }

    @Test("animatableData reflects phase")
    func animatableData() {
        var pattern = OceanArcPattern(phase: 1.5)
        #expect(pattern.animatableData == 1.5)
        pattern.animatableData = 3.0
        #expect(pattern.animatableData == 3.0)
    }

    @Test("Different phases produce different paths")
    func phaseChangesPath() {
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let pattern0 = OceanArcPattern(phase: 0)
        let patternPi = OceanArcPattern(phase: .pi)
        let bounds0 = pattern0.path(in: rect).boundingRect
        let boundsPi = patternPi.path(in: rect).boundingRect
        // Phase shift should offset arcs horizontally
        #expect(bounds0 != boundsPi)
    }

    @Test("Minimum columns and rows are clamped to 1")
    func minimumClamp() {
        let pattern = OceanArcPattern(columns: 0, ringsPerGroup: 0, rows: 0)
        let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
        // Should not crash and should produce valid path
        let path = pattern.path(in: rect)
        #expect(!path.isEmpty)
    }

    @Test("More columns produces wider arc distribution")
    func columnScaling() {
        let rect = CGRect(x: 0, y: 0, width: 400, height: 200)
        let few = OceanArcPattern(columns: 3, ringsPerGroup: 2, rows: 1)
        let many = OceanArcPattern(columns: 10, ringsPerGroup: 2, rows: 1)
        let fewBounds = few.path(in: rect).boundingRect
        let manyBounds = many.path(in: rect).boundingRect
        // More columns should produce a wider spread of arcs
        #expect(fewBounds != manyBounds)
    }
}
