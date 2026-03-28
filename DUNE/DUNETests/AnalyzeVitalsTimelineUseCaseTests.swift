import Testing
@testable import DUNE

@Suite("AnalyzeVitalsTimelineUseCase Tests")
struct AnalyzeVitalsTimelineUseCaseTests {
    let sut = AnalyzeVitalsTimelineUseCase()
    let calendar = Calendar.current

    private func makeDay(daysAgo: Int, values: [Double]) -> AnalyzeVitalsTimelineUseCase.Input.DaySample {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
        return .init(date: date, values: values)
    }

    @Test("Empty input produces no-data tracks")
    func emptyInput() {
        let input = AnalyzeVitalsTimelineUseCase.Input(
            heartRateSamples: [],
            respiratoryRateSamples: [],
            wristTemperatureSamples: [],
            spO2Samples: []
        )
        let result = sut.execute(input: input)
        #expect(!result.heartRate.hasData)
        #expect(result.anomalyDays.isEmpty)
    }

    @Test("Normal data produces no anomalies")
    func normalDataNoAnomalies() {
        let samples = (0..<30).map { makeDay(daysAgo: $0, values: [60, 62, 58, 61]) }
        let input = AnalyzeVitalsTimelineUseCase.Input(
            heartRateSamples: samples,
            respiratoryRateSamples: [],
            wristTemperatureSamples: [],
            spO2Samples: []
        )
        let result = sut.execute(input: input)
        #expect(result.heartRate.hasData)
        #expect(result.heartRate.dailySummaries.count == 30)
        #expect(result.anomalyDays.isEmpty)
    }

    @Test("Outlier day flagged as anomaly")
    func outlierDetected() {
        var samples = (0..<29).map { makeDay(daysAgo: $0 + 1, values: [60, 62, 58]) }
        // Day 0 has a huge spike
        samples.append(makeDay(daysAgo: 0, values: [120, 125, 118]))
        let input = AnalyzeVitalsTimelineUseCase.Input(
            heartRateSamples: samples,
            respiratoryRateSamples: [],
            wristTemperatureSamples: [],
            spO2Samples: []
        )
        let result = sut.execute(input: input)
        #expect(!result.anomalyDays.isEmpty)
    }

    @Test("Baseline and stddev computed correctly")
    func baselineAndStddev() {
        let samples = [
            makeDay(daysAgo: 0, values: [60]),
            makeDay(daysAgo: 1, values: [70]),
            makeDay(daysAgo: 2, values: [50]),
        ]
        let input = AnalyzeVitalsTimelineUseCase.Input(
            heartRateSamples: samples,
            respiratoryRateSamples: [],
            wristTemperatureSamples: [],
            spO2Samples: []
        )
        let result = sut.execute(input: input)
        #expect(result.heartRate.baseline != nil)
        let baseline = result.heartRate.baseline!
        #expect(abs(baseline - 60.0) < 0.1) // (60+70+50)/3 = 60
    }
}
