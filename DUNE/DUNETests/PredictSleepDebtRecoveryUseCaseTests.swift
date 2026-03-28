import Testing
@testable import DUNE

@Suite("PredictSleepDebtRecoveryUseCase Tests")
struct PredictSleepDebtRecoveryUseCaseTests {
    let sut = PredictSleepDebtRecoveryUseCase()

    private func makeDeficit(weeklyDeficit: Double, level: SleepDeficitAnalysis.DeficitLevel) -> SleepDeficitAnalysis {
        SleepDeficitAnalysis(
            shortTermAverage: 420,
            longTermAverage: 450,
            weeklyDeficit: weeklyDeficit,
            dailyDeficits: [],
            level: level,
            dataPointCount: 10
        )
    }

    @Test("Returns nil for good deficit level")
    func nilForGoodLevel() {
        let result = sut.execute(deficit: makeDeficit(weeklyDeficit: 60, level: .good))
        #expect(result == nil)
    }

    @Test("Returns nil for insufficient data")
    func nilForInsufficientData() {
        let result = sut.execute(deficit: makeDeficit(weeklyDeficit: 200, level: .insufficient))
        #expect(result == nil)
    }

    @Test("Returns nil for debt below threshold")
    func nilForLowDebt() {
        let result = sut.execute(deficit: makeDeficit(weeklyDeficit: 20, level: .mild))
        #expect(result == nil)
    }

    @Test("Predicts fast recovery for mild deficit")
    func fastRecoveryForMildDeficit() {
        let result = sut.execute(deficit: makeDeficit(weeklyDeficit: 120, level: .mild))
        #expect(result != nil)
        #expect(result!.estimatedRecoveryDays <= 3)
        #expect(result!.recoveryRate == .fast)
    }

    @Test("Predicts longer recovery for severe deficit")
    func longerRecoveryForSevereDeficit() {
        let result = sut.execute(deficit: makeDeficit(weeklyDeficit: 600, level: .severe))
        #expect(result != nil)
        #expect(result!.estimatedRecoveryDays > 3)
    }

    @Test("Projection starts at current debt and decreases")
    func projectionDecreasesMonotonically() {
        let result = sut.execute(deficit: makeDeficit(weeklyDeficit: 300, level: .moderate))!
        for i in 1..<result.dailyProjection.count {
            #expect(result.dailyProjection[i].projectedDebtMinutes <= result.dailyProjection[i - 1].projectedDebtMinutes)
        }
    }
}
