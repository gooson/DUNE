import Testing
@testable import DUNE
import Foundation

@Suite("AggregateNocturnalVitalsUseCase")
struct AggregateNocturnalVitalsUseCaseTests {

    private let sut = AggregateNocturnalVitalsUseCase()

    private var midnight: Date { Calendar.current.startOfDay(for: Date()) }
    private var sleepStart: Date { midnight.addingTimeInterval(-2 * 3600) } // 10pm
    private var sleepEnd: Date { midnight.addingTimeInterval(6 * 3600) }    // 6am

    private func sample(minutesAfterStart: Double, value: Double) -> AggregateNocturnalVitalsUseCase.Input.TimestampedValue {
        .init(date: sleepStart.addingTimeInterval(minutesAfterStart * 60), value: value)
    }

    // MARK: - Basic

    @Test("Returns nil for zero-duration sleep window")
    func zeroDuration() {
        let input = AggregateNocturnalVitalsUseCase.Input(
            sleepStart: midnight,
            sleepEnd: midnight,
            heartRateSamples: [],
            respiratoryRateSamples: [],
            wristTemperatureSamples: [],
            spO2Samples: [],
            wristTemperatureBaseline: nil
        )
        #expect(sut.execute(input: input) == nil)
    }

    @Test("8-hour sleep produces approximately 96 bucket starts")
    func eightHourBuckets() {
        // 8 hours = 480 min, 5-min buckets = 96
        let hrSamples = stride(from: 0.0, to: 480.0, by: 1.0).map { sample(minutesAfterStart: $0, value: 60) }
        let input = AggregateNocturnalVitalsUseCase.Input(
            sleepStart: sleepStart,
            sleepEnd: sleepEnd,
            heartRateSamples: hrSamples,
            respiratoryRateSamples: [],
            wristTemperatureSamples: [],
            spO2Samples: [],
            wristTemperatureBaseline: nil
        )
        let result = sut.execute(input: input)!
        #expect(result.heartRateBuckets.count == 96)
        #expect(result.respiratoryRateBuckets.isEmpty)
    }

    // MARK: - Summary

    @Test("Summary computes min and avg HR")
    func summaryHR() {
        let hrSamples = [
            sample(minutesAfterStart: 0, value: 50),
            sample(minutesAfterStart: 5, value: 60),
            sample(minutesAfterStart: 10, value: 55),
        ]
        let input = AggregateNocturnalVitalsUseCase.Input(
            sleepStart: sleepStart,
            sleepEnd: sleepEnd,
            heartRateSamples: hrSamples,
            respiratoryRateSamples: [],
            wristTemperatureSamples: [],
            spO2Samples: [],
            wristTemperatureBaseline: nil
        )
        let result = sut.execute(input: input)!
        #expect(result.summary.minHeartRate == 50)
        #expect(result.summary.avgHeartRate == 55) // (50+60+55)/3
    }

    @Test("Summary nil when no HR data")
    func summaryNilHR() {
        let input = AggregateNocturnalVitalsUseCase.Input(
            sleepStart: sleepStart,
            sleepEnd: sleepEnd,
            heartRateSamples: [],
            respiratoryRateSamples: [sample(minutesAfterStart: 0, value: 15)],
            wristTemperatureSamples: [],
            spO2Samples: [],
            wristTemperatureBaseline: nil
        )
        let result = sut.execute(input: input)!
        #expect(result.summary.minHeartRate == nil)
        #expect(result.summary.avgHeartRate == nil)
        #expect(result.summary.avgRespiratoryRate == 15)
    }

    // MARK: - Temperature deviation

    @Test("Wrist temp deviation calculated from baseline")
    func tempDeviation() {
        let tempSamples = [
            sample(minutesAfterStart: 0, value: 36.8),
            sample(minutesAfterStart: 5, value: 37.0),
        ]
        let input = AggregateNocturnalVitalsUseCase.Input(
            sleepStart: sleepStart,
            sleepEnd: sleepEnd,
            heartRateSamples: [],
            respiratoryRateSamples: [],
            wristTemperatureSamples: tempSamples,
            spO2Samples: [],
            wristTemperatureBaseline: 36.5
        )
        let result = sut.execute(input: input)!
        // avg = (36.8+37.0)/2 = 36.9, baseline = 36.5, deviation = +0.4
        #expect(result.summary.wristTempDeviation != nil)
        let dev = result.summary.wristTempDeviation!
        #expect(dev > 0.3 && dev < 0.5)
    }

    @Test("Wrist temp deviation nil without baseline")
    func tempDeviationNilWithoutBaseline() {
        let input = AggregateNocturnalVitalsUseCase.Input(
            sleepStart: sleepStart,
            sleepEnd: sleepEnd,
            heartRateSamples: [],
            respiratoryRateSamples: [],
            wristTemperatureSamples: [sample(minutesAfterStart: 0, value: 37.0)],
            spO2Samples: [],
            wristTemperatureBaseline: nil
        )
        let result = sut.execute(input: input)!
        #expect(result.summary.wristTempDeviation == nil)
    }

    // MARK: - Bucketing

    @Test("Bucket avg/min/max computed correctly")
    func bucketStats() {
        // 3 samples in first 5-minute bucket
        let hrSamples = [
            sample(minutesAfterStart: 0, value: 50),
            sample(minutesAfterStart: 2, value: 60),
            sample(minutesAfterStart: 4, value: 55),
        ]
        let input = AggregateNocturnalVitalsUseCase.Input(
            sleepStart: sleepStart,
            sleepEnd: sleepEnd,
            heartRateSamples: hrSamples,
            respiratoryRateSamples: [],
            wristTemperatureSamples: [],
            spO2Samples: [],
            wristTemperatureBaseline: nil
        )
        let result = sut.execute(input: input)!
        #expect(result.heartRateBuckets.count == 1)
        let bucket = result.heartRateBuckets[0]
        #expect(bucket.avg == 55) // (50+60+55)/3
        #expect(bucket.min == 50)
        #expect(bucket.max == 60)
    }

    // MARK: - Partial data

    @Test("Partial data: only SpO2 available")
    func partialData() {
        let input = AggregateNocturnalVitalsUseCase.Input(
            sleepStart: sleepStart,
            sleepEnd: sleepEnd,
            heartRateSamples: [],
            respiratoryRateSamples: [],
            wristTemperatureSamples: [],
            spO2Samples: [sample(minutesAfterStart: 0, value: 0.97)],
            wristTemperatureBaseline: nil
        )
        let result = sut.execute(input: input)!
        #expect(result.heartRateBuckets.isEmpty)
        #expect(result.spO2Buckets.count == 1)
        #expect(result.summary.avgSpO2 == 0.97)
    }
}
