import Testing
@testable import DUNE

@Suite("AnalyzeSleepEnvironmentUseCase Tests")
struct AnalyzeSleepEnvironmentUseCaseTests {
    let sut = AnalyzeSleepEnvironmentUseCase()
    let calendar = Calendar.current

    private func makePair(daysAgo: Int, score: Int, temp: Double, humidity: Double) -> AnalyzeSleepEnvironmentUseCase.Input.DayPair {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
        return .init(date: date, sleepScore: score, avgTemperatureCelsius: temp, avgHumidityPercent: humidity)
    }

    @Test("Returns nil for fewer than 7 data points")
    func nilForInsufficientData() {
        let pairs = (0..<5).map { makePair(daysAgo: $0, score: 75, temp: 20, humidity: 50) }
        let result = sut.execute(input: .init(pairs: pairs))
        #expect(result == nil)
    }

    @Test("Computes analysis for sufficient data")
    func computesAnalysis() {
        var pairs: [AnalyzeSleepEnvironmentUseCase.Input.DayPair] = []
        // Good sleep at moderate temps
        for i in 0..<10 {
            pairs.append(makePair(daysAgo: i, score: 85, temp: Double(18 + i % 4), humidity: 50))
        }
        // Bad sleep at extreme temps
        for i in 10..<20 {
            pairs.append(makePair(daysAgo: i, score: 50, temp: Double(30 + i % 5), humidity: 80))
        }
        let result = sut.execute(input: .init(pairs: pairs))
        #expect(result != nil)
        #expect(result!.dataPointCount == 20)
        #expect(result!.temperatureInsight != nil)
    }

    @Test("Confidence scales with sample size")
    func confidenceScaling() {
        let lowPairs = (0..<10).map { makePair(daysAgo: $0, score: 75, temp: 20, humidity: 50) }
        let lowResult = sut.execute(input: .init(pairs: lowPairs))
        #expect(lowResult?.confidence == .low)

        let highPairs = (0..<35).map { makePair(daysAgo: $0, score: 75, temp: 20, humidity: 50) }
        let highResult = sut.execute(input: .init(pairs: highPairs))
        #expect(highResult?.confidence == .high)
    }

    @Test("Zero scores are filtered out")
    func zeroScoresFiltered() {
        var pairs = (0..<10).map { makePair(daysAgo: $0, score: 75, temp: 20, humidity: 50) }
        pairs.append(makePair(daysAgo: 10, score: 0, temp: 20, humidity: 50))
        let result = sut.execute(input: .init(pairs: pairs))
        #expect(result?.dataPointCount == 10)
    }

    @Test("Temperature insight identifies optimal range")
    func temperatureOptimalRange() {
        var pairs: [AnalyzeSleepEnvironmentUseCase.Input.DayPair] = []
        // Best sleep around 20°C
        for i in 0..<8 {
            pairs.append(makePair(daysAgo: i, score: 90, temp: 19.0 + Double(i % 3), humidity: 50))
        }
        // Worst sleep around 32°C
        for i in 8..<16 {
            pairs.append(makePair(daysAgo: i, score: 45, temp: 31.0 + Double(i % 3), humidity: 50))
        }
        let result = sut.execute(input: .init(pairs: pairs))!
        #expect(result.temperatureInsight!.bestSleepAvgScore > result.temperatureInsight!.worstSleepAvgScore)
    }
}
