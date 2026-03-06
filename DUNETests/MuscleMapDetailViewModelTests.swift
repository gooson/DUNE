import Testing
import Foundation
@testable import DUNE

@Suite("MuscleMapDetailViewModel")
struct MuscleMapDetailViewModelTests {

    // MARK: - Helpers

    private func makeFatigueState(
        muscle: MuscleGroup,
        weeklyVolume: Int = 0,
        recoveryPercent: Double = 1.0,
        lastTrainedDate: Date? = nil
    ) -> MuscleFatigueState {
        MuscleFatigueState(
            muscle: muscle,
            lastTrainedDate: lastTrainedDate,
            hoursSinceLastTrained: lastTrainedDate.map { Date().timeIntervalSince($0) / 3600 },
            weeklyVolume: weeklyVolume,
            recoveryPercent: recoveryPercent,
            compoundScore: nil
        )
    }

    // MARK: - Empty State

    @Test("Empty fatigue states produces zero counts")
    @MainActor
    func emptyFatigueStates() {
        let vm = MuscleMapDetailViewModel()
        vm.loadData(fatigueStates: [])

        #expect(vm.recoveredCount == 0)
        #expect(vm.trainedCount == 0)
        #expect(vm.totalWeeklySets == 0)
        #expect(vm.overworkedMuscles.isEmpty)
        #expect(vm.nextRecovery == nil)
        #expect(vm.balanceInfo.isBalanced)
        #expect(vm.sortedMuscleVolumes.count == MuscleGroup.allCases.count)
    }

    // MARK: - All Recovered

    @Test("All muscles recovered when no recent training")
    @MainActor
    func allRecovered() {
        let states = MuscleGroup.allCases.map { makeFatigueState(muscle: $0) }
        let vm = MuscleMapDetailViewModel()
        vm.loadData(fatigueStates: states)

        // With no lastTrainedDate, fatigueLevel is .noData — isRecovered checks rawValue <= 3
        // .noData rawValue is 0, so all are "recovered"
        #expect(vm.recoveredCount == MuscleGroup.allCases.count)
        #expect(vm.trainedCount == 0)
        #expect(vm.totalWeeklySets == 0)
    }

    // MARK: - Volume Sorting

    @Test("Sorted muscle volumes are in descending order")
    @MainActor
    func volumeSorting() {
        let states = [
            makeFatigueState(muscle: .chest, weeklyVolume: 12),
            makeFatigueState(muscle: .back, weeklyVolume: 8),
            makeFatigueState(muscle: .quadriceps, weeklyVolume: 15),
        ]
        let vm = MuscleMapDetailViewModel()
        vm.loadData(fatigueStates: states)

        let topThree = vm.sortedMuscleVolumes.prefix(3)
        #expect(topThree[0].muscle == .quadriceps)
        #expect(topThree[0].volume == 15)
        #expect(topThree[1].muscle == .chest)
        #expect(topThree[1].volume == 12)
        #expect(topThree[2].muscle == .back)
        #expect(topThree[2].volume == 8)
    }

    // MARK: - Total Weekly Sets

    @Test("Total weekly sets sums all muscle volumes")
    @MainActor
    func totalWeeklySets() {
        let states = [
            makeFatigueState(muscle: .chest, weeklyVolume: 10),
            makeFatigueState(muscle: .back, weeklyVolume: 8),
            makeFatigueState(muscle: .biceps, weeklyVolume: 6),
        ]
        let vm = MuscleMapDetailViewModel()
        vm.loadData(fatigueStates: states)

        #expect(vm.totalWeeklySets == 24)
        #expect(vm.trainedCount == 3)
    }

    // MARK: - Balance

    @Test("Balanced when volumes are similar")
    @MainActor
    func balancedVolumes() {
        let states = [
            makeFatigueState(muscle: .chest, weeklyVolume: 10),
            makeFatigueState(muscle: .back, weeklyVolume: 9),
            makeFatigueState(muscle: .shoulders, weeklyVolume: 8),
        ]
        let vm = MuscleMapDetailViewModel()
        vm.loadData(fatigueStates: states)

        // max-min=2, avg=9, ratio=2/9≈0.22 < 1.5 → balanced
        #expect(vm.balanceInfo.isBalanced)
    }

    @Test("Unbalanced when volumes diverge significantly")
    @MainActor
    func unbalancedVolumes() {
        let states = [
            makeFatigueState(muscle: .chest, weeklyVolume: 20),
            makeFatigueState(muscle: .back, weeklyVolume: 2),
        ]
        let vm = MuscleMapDetailViewModel()
        vm.loadData(fatigueStates: states)

        // max-min=18, avg=11, ratio=18/11≈1.64 > 1.5 → unbalanced
        #expect(!vm.balanceInfo.isBalanced)
    }

    // MARK: - Selected Muscle

    @Test("Selected muscle toggles on/off")
    @MainActor
    func selectedMuscleToggle() {
        let vm = MuscleMapDetailViewModel()
        vm.loadData(fatigueStates: [makeFatigueState(muscle: .chest, weeklyVolume: 5)])

        vm.selectedMuscle = .chest
        #expect(vm.selectedMuscle == .chest)

        vm.selectedMuscle = nil
        #expect(vm.selectedMuscle == nil)
    }

    // MARK: - All Muscles Present

    @Test("All 13 muscle groups appear in sorted volumes even if not in fatigue states")
    @MainActor
    func allMuscleGroupsPresent() {
        let states = [makeFatigueState(muscle: .chest, weeklyVolume: 5)]
        let vm = MuscleMapDetailViewModel()
        vm.loadData(fatigueStates: states)

        #expect(vm.sortedMuscleVolumes.count == MuscleGroup.allCases.count)
        let chestEntry = vm.sortedMuscleVolumes.first { $0.muscle == .chest }
        #expect(chestEntry?.volume == 5)

        let calfEntry = vm.sortedMuscleVolumes.first { $0.muscle == .calves }
        #expect(calfEntry?.volume == 0)
    }

    // MARK: - Undertrained Muscles

    @Test("Undertrained muscles are correctly identified when imbalanced")
    @MainActor
    func undertrainedMuscles() {
        let states = [
            makeFatigueState(muscle: .chest, weeklyVolume: 20),
            makeFatigueState(muscle: .back, weeklyVolume: 3),
            makeFatigueState(muscle: .biceps, weeklyVolume: 2),
        ]
        let vm = MuscleMapDetailViewModel()
        vm.setWeeklySetGoal(15)
        vm.loadData(fatigueStates: states)

        // goalHalf = 7, back(3) and biceps(2) are < 7 and > 0
        #expect(!vm.balanceInfo.isBalanced)
        #expect(vm.balanceInfo.undertrainedMuscles.contains(.back))
        #expect(vm.balanceInfo.undertrainedMuscles.contains(.biceps))
    }

    // MARK: - Fatigue Index

    @Test("Fatigue by muscle dictionary is correctly indexed")
    @MainActor
    func fatigueIndex() {
        let states = [
            makeFatigueState(muscle: .chest, weeklyVolume: 10),
            makeFatigueState(muscle: .back, weeklyVolume: 8),
        ]
        let vm = MuscleMapDetailViewModel()
        vm.loadData(fatigueStates: states)

        #expect(vm.fatigueByMuscle[.chest]?.weeklyVolume == 10)
        #expect(vm.fatigueByMuscle[.back]?.weeklyVolume == 8)
        #expect(vm.fatigueByMuscle[.biceps] == nil)
    }
}

@Suite("MuscleMap3DState")
struct MuscleMap3DStateTests {

    private func makeFatigueState(
        muscle: MuscleGroup,
        weeklyVolume: Int = 0,
        recoveryPercent: Double = 1.0,
        lastTrainedDate: Date? = nil
    ) -> MuscleFatigueState {
        MuscleFatigueState(
            muscle: muscle,
            lastTrainedDate: lastTrainedDate,
            hoursSinceLastTrained: lastTrainedDate.map { Date().timeIntervalSince($0) / 3600 },
            weeklyVolume: weeklyVolume,
            recoveryPercent: recoveryPercent,
            compoundScore: nil
        )
    }

    @Test("Default selection prefers highlighted muscle")
    func defaultSelectionPrefersHighlight() {
        let selection = MuscleMap3DState.defaultSelectedMuscle(
            highlighted: .traps,
            fatigueStates: [
                makeFatigueState(muscle: .chest, weeklyVolume: 16),
                makeFatigueState(muscle: .back, weeklyVolume: 8),
            ]
        )

        #expect(selection == .traps)
    }

    @Test("Default selection falls back to the highest weekly volume")
    func defaultSelectionPrefersHighestVolume() {
        let selection = MuscleMap3DState.defaultSelectedMuscle(
            highlighted: nil,
            fatigueStates: [
                makeFatigueState(muscle: .chest, weeklyVolume: 8),
                makeFatigueState(muscle: .quadriceps, weeklyVolume: 18),
                makeFatigueState(muscle: .back, weeklyVolume: 12),
            ]
        )

        #expect(selection == .quadriceps)
    }

    @Test("Display state uses fatigue level in recovery mode")
    func recoveryDisplayState() {
        let fatigueByMuscle = [
            MuscleGroup.chest: makeFatigueState(
                muscle: .chest,
                weeklyVolume: 6,
                recoveryPercent: 0.55,
                lastTrainedDate: Date().addingTimeInterval(-3600 * 8)
            )
        ]

        let state = MuscleMap3DState.displayState(
            for: .chest,
            fatigueByMuscle: fatigueByMuscle,
            mode: .recovery
        )

        #expect(state == .recovery(.moderateFatigue))
    }

    @Test("Display state uses volume intensity in volume mode")
    func volumeDisplayState() {
        let fatigueByMuscle = [
            MuscleGroup.back: makeFatigueState(muscle: .back, weeklyVolume: 14)
        ]

        let state = MuscleMap3DState.displayState(
            for: .back,
            fatigueByMuscle: fatigueByMuscle,
            mode: .volume
        )

        #expect(state == .volume(.high))
    }

    @Test("Zoom scale is clamped to viewer bounds")
    func zoomScaleClamped() {
        #expect(MuscleMap3DState.clampedZoomScale(0.2) == MuscleMap3DState.minZoomScale)
        #expect(MuscleMap3DState.clampedZoomScale(2.4) == MuscleMap3DState.maxZoomScale)
    }

    @Test("Yaw normalization keeps angles in 0 to 360 degrees")
    func yawNormalized() {
        #expect(abs(MuscleMap3DState.normalizedYaw(-.pi / 2) - 270) < 0.001)
        #expect(abs(MuscleMap3DState.normalizedYaw(.pi * 3) - 180) < 0.001)
    }

    @Test("Back muscles prefer a rear-facing camera angle")
    func preferredYawForRearMuscles() {
        let chestYaw = MuscleMap3DState.preferredYaw(for: .chest)
        let backYaw = MuscleMap3DState.preferredYaw(for: .back)

        #expect(chestYaw == MuscleMap3DState.defaultYaw)
        #expect(backYaw > .pi)
    }

    @Test("SVG-derived 3D geometry covers all muscle groups")
    func geometryCoversAllMuscles() {
        let coveredMuscles = Set(MuscleMap3DGeometry.allEntries.map(\.descriptor.muscle))
        #expect(coveredMuscles == Set(MuscleGroup.allCases))
    }

    @Test("Front and back SVG parts map to the expected planes")
    func partPlanesMatchExpectedSides() {
        let frontChest = MuscleMap3DGeometry.descriptor(for: "front-chest")
        let backGlutes = MuscleMap3DGeometry.descriptor(for: "back-glutes")

        #expect(frontChest?.plane == .front)
        #expect(backGlutes?.plane == .back)
    }

    @Test("Backside muscles use a negative z offset")
    func backsideOffsetsAreNegative() {
        let descriptor = MuscleMap3DGeometry.descriptor(for: "back-hamstrings")
        #expect(descriptor?.zOffset == MuscleMap3DGeometry.backLayerZ)
        #expect(descriptor?.zOffset ?? 0 < 0)
    }
}
