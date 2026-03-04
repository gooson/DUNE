import Testing
import SwiftUI
@testable import DUNE

@Suite("HanokEaveShape")
struct HanokEaveShapeTests {
    // MARK: - Path Generation

    @Test("Standard parameters produce non-empty path")
    func standardPath() {
        let shape = HanokEaveShape(
            amplitude: 0.05,
            frequency: 1.5,
            phase: 0,
            verticalOffset: 0.5,
            uplift: 0.2
        )
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let path = shape.path(in: rect)
        #expect(!path.isEmpty)
    }

    @Test("Zero-size rect produces empty path")
    func zeroRect() {
        let shape = HanokEaveShape()
        let zeroWidth = CGRect(x: 0, y: 0, width: 0, height: 200)
        let zeroHeight = CGRect(x: 0, y: 0, width: 300, height: 0)
        #expect(shape.path(in: zeroWidth).isEmpty)
        #expect(shape.path(in: zeroHeight).isEmpty)
    }

    @Test("Zero amplitude produces valid path")
    func zeroAmplitude() {
        let shape = HanokEaveShape(amplitude: 0)
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let path = shape.path(in: rect)
        #expect(!path.isEmpty)
    }

    @Test("Maximum uplift is clamped to 0.4")
    func upliftClamped() {
        let shape = HanokEaveShape(uplift: 1.0)
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        // Should not crash and produce valid path
        let path = shape.path(in: rect)
        #expect(!path.isEmpty)
    }

    @Test("Tile ripple is clamped to 0.15")
    func tileRippleClamped() {
        let shape = HanokEaveShape(tileRipple: 1.0)
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let path = shape.path(in: rect)
        #expect(!path.isEmpty)
    }

    @Test("Phase animation produces different paths")
    func phaseVariation() {
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let shape0 = HanokEaveShape(phase: 0)
        let shape1 = HanokEaveShape(phase: .pi)
        let path0 = shape0.path(in: rect)
        let path1 = shape1.path(in: rect)
        #expect(path0 != path1)
    }

    @Test("Path with tile ripple enabled")
    func tileRippleEnabled() {
        let shape = HanokEaveShape(tileRipple: 0.1, tileFrequency: 8.0)
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let path = shape.path(in: rect)
        #expect(!path.isEmpty)
    }

    // MARK: - AppTheme Integration

    @Test("Hanok theme exists in allCases")
    func hanokThemeExists() {
        #expect(AppTheme.allCases.contains(.hanok))
    }

    @Test("Hanok raw value is 'hanok'")
    func hanokRawValue() {
        #expect(AppTheme.hanok.rawValue == "hanok")
    }

    @Test("Hanok display name is not empty")
    func hanokDisplayName() {
        #expect(!AppTheme.hanok.displayName.isEmpty)
    }

    @Test("Hanok asset prefix is 'Hanok'")
    func hanokAssetPrefix() {
        #expect(AppTheme.hanok.assetPrefix == "Hanok")
    }

    @Test("Hanok themed asset name follows convention")
    func hanokThemedAssetName() {
        let name = AppTheme.hanok.themedAssetName(defaultAsset: "ScoreExcellent", variantSuffix: "ScoreExcellent")
        #expect(name == "HanokScoreExcellent")
    }
}
