import Testing
import simd
@testable import DUNE

@Suite("MuscleMap3DState volume scale mapping")
struct MuscleMap3DStateTests {

    @Test("volumeScale returns identity for .none")
    func volumeScaleNone() {
        let scale = MuscleMap3DState.volumeScale(for: .none)
        #expect(scale == SIMD3<Float>(1.0, 1.0, 1.0))
    }

    @Test("volumeScale returns light expansion")
    func volumeScaleLight() {
        let scale = MuscleMap3DState.volumeScale(for: .light)
        #expect(scale == SIMD3<Float>(1.02, 1.01, 1.02))
    }

    @Test("volumeScale returns moderate expansion")
    func volumeScaleModerate() {
        let scale = MuscleMap3DState.volumeScale(for: .moderate)
        #expect(scale == SIMD3<Float>(1.05, 1.02, 1.05))
    }

    @Test("volumeScale returns high expansion")
    func volumeScaleHigh() {
        let scale = MuscleMap3DState.volumeScale(for: .high)
        #expect(scale == SIMD3<Float>(1.09, 1.03, 1.09))
    }

    @Test("volumeScale returns veryHigh expansion")
    func volumeScaleVeryHigh() {
        let scale = MuscleMap3DState.volumeScale(for: .veryHigh)
        #expect(scale == SIMD3<Float>(1.14, 1.04, 1.14))
    }

    @Test("X/Z expand more than Y for all non-none intensities")
    func xzExpandMoreThanY() {
        for intensity in MuscleMap3DVolumeIntensity.allCases where intensity != .none {
            let scale = MuscleMap3DState.volumeScale(for: intensity)
            #expect(scale.x > scale.y, "X should be greater than Y for \(intensity)")
            #expect(scale.z > scale.y, "Z should be greater than Y for \(intensity)")
            #expect(scale.x == scale.z, "X and Z should be equal for \(intensity)")
        }
    }

    @Test("volumeScale increases monotonically with intensity")
    func monotonicallyIncreasing() {
        let intensities = MuscleMap3DVolumeIntensity.allCases.sorted { $0.rawValue < $1.rawValue }
        for i in 1..<intensities.count {
            let prev = MuscleMap3DState.volumeScale(for: intensities[i - 1])
            let curr = MuscleMap3DState.volumeScale(for: intensities[i])
            #expect(curr.x >= prev.x, "X should increase from \(intensities[i-1]) to \(intensities[i])")
            #expect(curr.y >= prev.y, "Y should increase from \(intensities[i-1]) to \(intensities[i])")
        }
    }

    @Test("selection scale combined with volume scale is multiplicative")
    func selectionTimesVolumeIsMultiplicative() {
        let volumeScale = MuscleMap3DState.volumeScale(for: .high)
        let selectionScale = MuscleMap3DState.selectedScale
        let combined = volumeScale * selectionScale

        #expect(combined.x == volumeScale.x * selectionScale)
        #expect(combined.y == volumeScale.y * selectionScale)
        #expect(combined.z == volumeScale.z * selectionScale)
    }
}
