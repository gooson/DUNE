import Testing
import SwiftUI
@testable import DUNE

@Suite("DalhangariWaveShape")
struct DalhangariWaveShapeTests {
    // MARK: - Path Generation

    @Test("Standard parameters produce non-empty path")
    func standardPath() {
        let shape = DalhangariWaveShape(
            amplitude: 0.05,
            frequency: 1.5,
            phase: 0,
            verticalOffset: 0.5,
            asymmetry: 0.3,
            organicBlend: 0.15
        )
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let path = shape.path(in: rect)
        #expect(!path.isEmpty)
    }

    @Test("Zero-size rect produces empty path")
    func zeroRect() {
        let shape = DalhangariWaveShape()
        let zeroWidth = CGRect(x: 0, y: 0, width: 0, height: 200)
        let zeroHeight = CGRect(x: 0, y: 0, width: 300, height: 0)
        #expect(shape.path(in: zeroWidth).isEmpty)
        #expect(shape.path(in: zeroHeight).isEmpty)
    }

    @Test("Zero amplitude produces valid path")
    func zeroAmplitude() {
        let shape = DalhangariWaveShape(amplitude: 0)
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let path = shape.path(in: rect)
        #expect(!path.isEmpty)
    }

    @Test("Asymmetry zero produces symmetric wave")
    func symmetricWhenNoAsymmetry() {
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let shape = DalhangariWaveShape(asymmetry: 0, organicBlend: 0)
        let path = shape.path(in: rect)
        #expect(!path.isEmpty)
    }

    @Test("Asymmetry greater than zero produces asymmetric wave")
    func asymmetricWave() {
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let symmetric = DalhangariWaveShape(asymmetry: 0, organicBlend: 0)
        let asymmetric = DalhangariWaveShape(asymmetry: 0.3, organicBlend: 0)
        let pathSym = symmetric.path(in: rect)
        let pathAsym = asymmetric.path(in: rect)
        #expect(pathSym != pathAsym)
    }

    @Test("Asymmetry is clamped to 0.5")
    func asymmetryClamped() {
        let shape = DalhangariWaveShape(asymmetry: 1.0)
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let path = shape.path(in: rect)
        #expect(!path.isEmpty)
    }

    @Test("OrganicBlend is clamped to 0.3")
    func organicBlendClamped() {
        let shape = DalhangariWaveShape(organicBlend: 1.0)
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let path = shape.path(in: rect)
        #expect(!path.isEmpty)
    }

    @Test("Phase animation produces different paths")
    func phaseVariation() {
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let shape0 = DalhangariWaveShape(phase: 0)
        let shape1 = DalhangariWaveShape(phase: .pi)
        let path0 = shape0.path(in: rect)
        let path1 = shape1.path(in: rect)
        #expect(path0 != path1)
    }

    @Test("AnimatableData reflects phase")
    func animatableData() {
        var shape = DalhangariWaveShape(phase: 1.5)
        #expect(shape.animatableData == 1.5)

        shape.animatableData = 3.0
        #expect(shape.animatableData == 3.0)
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
