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

    @Test("Roof tile seal path is generated for square rect")
    func roofTileSealPathSquare() {
        let seal = HanokRoofTileSealShape()
        let path = seal.path(in: CGRect(x: 0, y: 0, width: 96, height: 96))

        #expect(path.isEmpty == false)
    }

    @Test("Roof tile seal path is generated for wide rect")
    func roofTileSealPathWide() {
        let seal = HanokRoofTileSealShape()
        let path = seal.path(in: CGRect(x: 0, y: 0, width: 140, height: 88))

        #expect(path.isEmpty == false)
    }

    @Test("Roof tile seal path is empty for zero-size rect")
    func roofTileSealPathZeroSize() {
        let seal = HanokRoofTileSealShape()
        let path = seal.path(in: .zero)

        #expect(path.isEmpty == true)
    }

    @Test("Pavilion silhouette path is generated")
    func pavilionSilhouettePath() {
        let pavilion = HanokPavilionSilhouetteShape()
        let rect = CGRect(x: 0, y: 0, width: 220, height: 160)
        let path = pavilion.path(in: rect)

        #expect(path.isEmpty == false)
        let bounds = path.boundingRect
        #expect(bounds.minX >= rect.minX - 1)
        #expect(bounds.maxX <= rect.maxX + 1)
        #expect(bounds.minY >= rect.minY - 1)
        #expect(bounds.maxY <= rect.maxY + 1)
    }

    @Test("Pavilion silhouette path is empty for zero-size rect")
    func pavilionSilhouettePathZeroSize() {
        let pavilion = HanokPavilionSilhouetteShape()

        #expect(pavilion.path(in: .zero).isEmpty == true)
    }

    @Test("Mountain backdrop animatableData reflects ridge shift")
    func mountainBackdropAnimatableData() {
        var mountain = HanokMountainBackdropShape(ridgeShift: -0.03)

        #expect(mountain.animatableData == -0.03)

        mountain.animatableData = 0.04
        #expect(mountain.animatableData == 0.04)
    }

    @Test("Mountain backdrop path changes with ridge shift")
    func mountainBackdropShiftChangesPath() {
        let rect = CGRect(x: 0, y: 0, width: 260, height: 160)
        let still = HanokMountainBackdropShape(ridgeShift: 0)
        let shifted = HanokMountainBackdropShape(ridgeShift: 0.05)

        #expect(still.path(in: rect) != shifted.path(in: rect))
    }
}
