import Foundation
import SwiftUI
import Testing
@testable import DUNE

@Suite("OceanWaveShape Geometry")
struct OceanWaveShapeTests {
    @Test("Path is non-empty for valid rect")
    func pathNonEmpty() {
        let wave = OceanWaveShape()
        let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
        let path = wave.path(in: rect)
        #expect(!path.isEmpty)
    }

    @Test("Path is empty for zero-size rect")
    func pathEmptyForZeroRect() {
        let wave = OceanWaveShape()
        #expect(wave.path(in: .zero).isEmpty)
        #expect(wave.path(in: CGRect(x: 0, y: 0, width: 0, height: 100)).isEmpty)
        #expect(wave.path(in: CGRect(x: 0, y: 0, width: 100, height: 0)).isEmpty)
    }

    @Test("Path stays within rect bounds")
    func pathWithinBounds() {
        let wave = OceanWaveShape(amplitude: 0.3, frequency: 3, steepness: 0.4)
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let bounds = wave.path(in: rect).boundingRect
        #expect(bounds.minX >= rect.minX - 1)
        #expect(bounds.maxX <= rect.maxX + 1)
        #expect(bounds.minY >= rect.minY - 1)
        #expect(bounds.maxY <= rect.maxY + 1)
    }

    @Test("Steepness creates asymmetric crests vs troughs")
    func steepnessAsymmetry() {
        let rect = CGRect(x: 0, y: 0, width: 400, height: 200)
        let symmetric = OceanWaveShape(amplitude: 0.2, frequency: 2, phase: 0, verticalOffset: 0.5, steepness: 0)
        let asymmetric = OceanWaveShape(amplitude: 0.2, frequency: 2, phase: 0, verticalOffset: 0.5, steepness: 0.4)

        let symBounds = symmetric.path(in: rect).boundingRect
        let asymBounds = asymmetric.path(in: rect).boundingRect

        // Asymmetric wave should have different vertical extent due to harmonic addition
        let symHeight = symBounds.height
        let asymHeight = asymBounds.height
        #expect(asymHeight != symHeight)
    }

    @Test("animatableData reflects phase")
    func animatableData() {
        var wave = OceanWaveShape(phase: 1.5)
        #expect(wave.animatableData == 1.5)
        wave.animatableData = 3.0
        #expect(wave.animatableData == 3.0)
    }

    @Test("Different phases produce different paths")
    func phaseChangesPath() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
        let wave0 = OceanWaveShape(phase: 0)
        let wavePi = OceanWaveShape(phase: .pi)
        let path0 = wave0.path(in: rect)
        let pathPi = wavePi.path(in: rect)

        // Start points should differ due to phase shift
        let start0 = firstWavePoint(from: path0)
        let startPi = firstWavePoint(from: pathPi)
        #expect(start0 != nil)
        #expect(startPi != nil)
        if let start0, let startPi {
            #expect(abs(start0.y - startPi.y) > 0.1)
        }
    }

    @Test("Zero amplitude produces flat wave")
    func zeroAmplitude() {
        let wave = OceanWaveShape(amplitude: 0, verticalOffset: 0.5)
        let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
        let bounds = wave.path(in: rect).boundingRect
        // Wave line at 50pt, fill to bottom = 100pt
        #expect(bounds.minY >= 49 && bounds.minY <= 51)
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
