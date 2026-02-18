import Foundation
import Testing
@testable import Dailve

@Suite("HeartRateQueryService BPM Validation")
struct HeartRateQueryServiceTests {

    private let testDate = Date()

    // MARK: - Valid Range

    @Test("Normal BPM (72) returns sample")
    func normalBPM() {
        let sample = HeartRateQueryService.validatedSample(bpm: 72, date: testDate)
        #expect(sample != nil)
        #expect(sample?.bpm == 72)
    }

    @Test("Lower bound (20) returns sample")
    func lowerBound() {
        let sample = HeartRateQueryService.validatedSample(bpm: 20, date: testDate)
        #expect(sample != nil)
        #expect(sample?.bpm == 20)
    }

    @Test("Upper bound (300) returns sample")
    func upperBound() {
        let sample = HeartRateQueryService.validatedSample(bpm: 300, date: testDate)
        #expect(sample != nil)
        #expect(sample?.bpm == 300)
    }

    @Test("High workout HR (195) returns sample")
    func highWorkoutHR() {
        let sample = HeartRateQueryService.validatedSample(bpm: 195, date: testDate)
        #expect(sample != nil)
    }

    // MARK: - Out of Range

    @Test("Below minimum (19) returns nil")
    func belowMinimum() {
        let sample = HeartRateQueryService.validatedSample(bpm: 19, date: testDate)
        #expect(sample == nil)
    }

    @Test("Above maximum (301) returns nil")
    func aboveMaximum() {
        let sample = HeartRateQueryService.validatedSample(bpm: 301, date: testDate)
        #expect(sample == nil)
    }

    @Test("Zero BPM returns nil")
    func zeroBPM() {
        let sample = HeartRateQueryService.validatedSample(bpm: 0, date: testDate)
        #expect(sample == nil)
    }

    @Test("Negative BPM returns nil")
    func negativeBPM() {
        let sample = HeartRateQueryService.validatedSample(bpm: -10, date: testDate)
        #expect(sample == nil)
    }

    @Test("Extremely high BPM (1000) returns nil")
    func sensorErrorBPM() {
        let sample = HeartRateQueryService.validatedSample(bpm: 1000, date: testDate)
        #expect(sample == nil)
    }

    // MARK: - Date Preservation

    @Test("Validated sample preserves date")
    func datePreserved() {
        let specificDate = Date(timeIntervalSince1970: 1000000)
        let sample = HeartRateQueryService.validatedSample(bpm: 120, date: specificDate)
        #expect(sample?.date == specificDate)
    }
}

@Suite("HeartRateSample Model")
struct HeartRateSampleTests {

    @Test("HeartRateSample stores bpm and date")
    func basicInit() {
        let date = Date()
        let sample = HeartRateSample(bpm: 85.5, date: date)
        #expect(sample.bpm == 85.5)
        #expect(sample.date == date)
    }
}

// MARK: - Downsampling Tests

@Suite("HeartRateQueryService Downsampling")
struct HeartRateDownsamplingTests {

    private let origin = Date(timeIntervalSinceReferenceDate: 0)

    private func sample(at secondsOffset: TimeInterval, bpm: Double) -> HeartRateSample {
        HeartRateSample(bpm: bpm, date: origin.addingTimeInterval(secondsOffset))
    }

    @Test("Empty array returns empty array")
    func emptyInput() {
        let result = HeartRateQueryService.downsample([])
        #expect(result.isEmpty)
    }

    @Test("Single sample returns same sample")
    func singleSample() {
        let input = [sample(at: 0, bpm: 72)]
        let result = HeartRateQueryService.downsample(input)
        #expect(result.count == 1)
        #expect(result.first?.bpm == 72)
    }

    @Test("Samples within same 10s bucket are averaged")
    func sameBucket() {
        let input = [
            sample(at: 0, bpm: 60),
            sample(at: 3, bpm: 80),
            sample(at: 7, bpm: 100),
        ]
        let result = HeartRateQueryService.downsample(input, intervalSeconds: 10)
        #expect(result.count == 1)
        #expect(result.first?.bpm == 80) // (60+80+100)/3
    }

    @Test("30s data with 10s interval produces 3 buckets")
    func multipleBuckets() {
        let input = [
            sample(at: 0, bpm: 60),  // bucket 0
            sample(at: 5, bpm: 70),  // bucket 0
            sample(at: 10, bpm: 80), // bucket 1
            sample(at: 15, bpm: 90), // bucket 1
            sample(at: 20, bpm: 100), // bucket 2
            sample(at: 25, bpm: 110), // bucket 2
        ]
        let result = HeartRateQueryService.downsample(input, intervalSeconds: 10)
        #expect(result.count == 3)
        #expect(result[0].bpm == 65)  // (60+70)/2
        #expect(result[1].bpm == 85)  // (80+90)/2
        #expect(result[2].bpm == 105) // (100+110)/2
    }

    @Test("Bucket midpoint date is used")
    func bucketMidpointDate() {
        let input = [
            sample(at: 0, bpm: 70),
            sample(at: 5, bpm: 80),
        ]
        let result = HeartRateQueryService.downsample(input, intervalSeconds: 10)
        #expect(result.count == 1)
        // Midpoint of bucket 0: origin + 5s
        let expectedDate = origin.addingTimeInterval(5)
        #expect(result.first?.date == expectedDate)
    }

    @Test("Sparse samples across distant buckets")
    func sparseSamples() {
        let input = [
            sample(at: 0, bpm: 60),   // bucket 0
            sample(at: 50, bpm: 90),  // bucket 5
            sample(at: 100, bpm: 120), // bucket 10
        ]
        let result = HeartRateQueryService.downsample(input, intervalSeconds: 10)
        #expect(result.count == 3)
        #expect(result[0].bpm == 60)
        #expect(result[1].bpm == 90)
        #expect(result[2].bpm == 120)
    }

    @Test("Results are sorted chronologically")
    func sortedOutput() {
        let input = [
            sample(at: 20, bpm: 100),
            sample(at: 0, bpm: 60),
            sample(at: 10, bpm: 80),
        ]
        let result = HeartRateQueryService.downsample(input, intervalSeconds: 10)
        #expect(result.count == 3)
        // Should be in chronological order regardless of input order
        #expect(result[0].bpm == 60)
        #expect(result[1].bpm == 80)
        #expect(result[2].bpm == 100)
    }
}

// MARK: - HeartRateSummary Tests

@Suite("HeartRateSummary")
struct HeartRateSummaryTests {

    @Test("isEmpty is true when no samples")
    func emptySummary() {
        let summary = HeartRateSummary(average: 0, max: 0, min: 0, samples: [])
        #expect(summary.isEmpty)
    }

    @Test("isEmpty is false when samples exist")
    func nonEmptySummary() {
        let summary = HeartRateSummary(
            average: 80,
            max: 100,
            min: 60,
            samples: [HeartRateSample(bpm: 80, date: Date())]
        )
        #expect(!summary.isEmpty)
    }

    @Test("Summary stores all properties correctly")
    func propertiesStored() {
        let samples = [
            HeartRateSample(bpm: 60, date: Date()),
            HeartRateSample(bpm: 80, date: Date()),
            HeartRateSample(bpm: 100, date: Date()),
        ]
        let summary = HeartRateSummary(average: 80, max: 100, min: 60, samples: samples)
        #expect(summary.average == 80)
        #expect(summary.max == 100)
        #expect(summary.min == 60)
        #expect(summary.samples.count == 3)
    }
}
