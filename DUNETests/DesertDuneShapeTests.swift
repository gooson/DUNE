import Foundation
import SwiftUI
import Testing
@testable import DUNE

@Suite("DesertDuneShape Geometry")
struct DesertDuneShapeTests {
    @Test("Path is non-empty for valid rect")
    func pathNonEmpty() {
        let dune = DesertDuneShape()
        let rect = CGRect(x: 0, y: 0, width: 240, height: 140)
        #expect(!dune.path(in: rect).isEmpty)
    }

    @Test("Path is empty for zero-size rect")
    func pathEmptyForZeroRect() {
        let dune = DesertDuneShape()
        #expect(dune.path(in: .zero).isEmpty)
        #expect(dune.path(in: CGRect(x: 0, y: 0, width: 0, height: 120)).isEmpty)
        #expect(dune.path(in: CGRect(x: 0, y: 0, width: 120, height: 0)).isEmpty)
    }

    @Test("animatableData reflects phase")
    func animatableData() {
        var dune = DesertDuneShape(phase: 1.2)
        #expect(dune.animatableData == 1.2)
        dune.animatableData = 2.4
        #expect(dune.animatableData == 2.4)
    }

    @Test("Skewness is clamped at init")
    func skewnessClamped() {
        let rect = CGRect(x: 0, y: 0, width: 280, height: 150)
        let maxSkew = DesertDuneShape(amplitude: 0.08, frequency: 1.2, skewness: 0.5)
        let overSkew = DesertDuneShape(amplitude: 0.08, frequency: 1.2, skewness: 0.9)
        let maxBounds = maxSkew.path(in: rect).boundingRect
        let overBounds = overSkew.path(in: rect).boundingRect

        #expect(abs(maxBounds.minY - overBounds.minY) < 0.01)
        #expect(abs(maxBounds.maxY - overBounds.maxY) < 0.01)
    }

    @Test("Ripple remains subtle even at high input")
    func rippleIsSubtle() {
        let rect = CGRect(x: 0, y: 0, width: 320, height: 180)
        let base = DesertDuneShape(amplitude: 0.1, frequency: 1.3, ripple: 0)
        let highRipple = DesertDuneShape(amplitude: 0.1, frequency: 1.3, ripple: 1.0, rippleFrequency: 7)

        let baseBounds = base.path(in: rect).boundingRect
        let rippleBounds = highRipple.path(in: rect).boundingRect

        #expect(abs(baseBounds.minY - rippleBounds.minY) < 6)
        #expect(abs(baseBounds.maxY - rippleBounds.maxY) < 6)
    }
}

