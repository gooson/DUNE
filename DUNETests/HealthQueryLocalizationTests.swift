import Foundation
import Testing
@testable import DUNE

@Suite("Health query request localization")
@MainActor
struct HealthQueryLocalizationTests {
    @Test("Concurrent queries keep their number formats across actor hops")
    func concurrentRequestLocales() async {
        let original = HealthQueryLocalization.locale
        let service = HealthQueryService()
        let formatted = await withTaskGroup(of: (String, String).self, returning: [String: String].self) { group in
            for identifier in ["en_US", "de_DE"] {
                group.addTask {
                    await HealthQueryLocalization.$locale.withValue(Locale(identifier: identifier)) {
                        await Task.yield()
                        let number = await service.number(1_234.5, digits: 1)
                        return (HealthQueryLocalization.locale.identifier, number)
                    }
                }
            }
            var results: [String: String] = [:]
            for await (identifier, value) in group { results[identifier] = value }
            return results
        }
        #expect(formatted["en_US"] == "1,234.5")
        #expect(formatted["de_DE"] == "1.234,5")
        #expect(HealthQueryLocalization.locale == original)
    }

    @Test("Nested request locale restores its parent after an error")
    func scopedLocaleRestoration() async {
        let original = HealthQueryLocalization.locale
        await HealthQueryLocalization.$locale.withValue(Locale(identifier: "ko_KR")) {
            do {
                try await HealthQueryLocalization.$locale.withValue(Locale(identifier: "ja_JP")) {
                    await Task.yield()
                    #expect(HealthQueryLocalization.locale.identifier == "ja_JP")
                    throw CancellationError()
                }
            } catch is CancellationError {
                #expect(HealthQueryLocalization.locale.identifier == "ko_KR")
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
        #expect(HealthQueryLocalization.locale == original)
    }

    @Test("Measurement dates use the invoking locale")
    func localizedMeasurementDate() {
        let service = HealthQueryService()
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let korean = HealthQueryLocalization.$locale.withValue(Locale(identifier: "ko_KR")) {
            service.dateText(date)
        }
        let english = HealthQueryLocalization.$locale.withValue(Locale(identifier: "en_US")) {
            service.dateText(date)
        }
        #expect(korean != english)
    }

    @Test("Response titles use the request language independently of app preferences",
          .enabled(if: Bundle.main.localizations.contains("ko") && Bundle.main.localizations.contains("ja"),
                   "Requires app localization resources"))
    func requestLanguageLookup() {
        for (identifier, expected) in [("en_US", "Latest Workout"),
                                       ("ko_KR", "최근 운동"),
                                       ("ja_JP", "最近のワークアウト")] {
            let title = HealthQueryLocalization.$locale.withValue(Locale(identifier: identifier)) {
                HealthQueryService.title(for: .latestWorkout)
            }
            #expect(title == expected)
        }
    }

    @Test("Concurrent translated responses keep their request language across actor hops",
          .enabled(if: Bundle.main.localizations.contains("ko"), "Requires app localization resources"))
    func concurrentResponseLanguages() async throws {
        let service = HealthQueryService(protectedDataProvider: { false })
        let titles = try await withThrowingTaskGroup(of: (String, String).self,
                                                    returning: [String: String].self) { group in
            for identifier in ["en_US", "ko_KR"] {
                group.addTask {
                    try await HealthQueryLocalization.$locale.withValue(Locale(identifier: identifier)) {
                        await Task.yield()
                        let result = try await service.execute(HealthQueryRequest(kind: .latestWorkout))
                        return (identifier, result.title)
                    }
                }
            }
            var results: [String: String] = [:]
            for try await (identifier, title) in group { results[identifier] = title }
            return results
        }
        #expect(titles["en_US"] == "Latest Workout")
        #expect(titles["ko_KR"] == "최근 운동")
    }

    @Test("Spoken measurements use Korean natural units",
          .enabled(if: Bundle.main.localizations.contains("ko"), "Requires app localization resources"))
    func koreanSpokenUnits() {
        let service = HealthQueryService()
        HealthQueryLocalization.$locale.withValue(Locale(identifier: "ko_KR")) {
            let weight = HealthQueryMetric(id: "weight", title: "Weight", value: 75.5, unit: .kilograms)
            let duration = HealthQueryMetric(id: "duration", title: "Duration", value: 3_661, unit: .seconds)
            #expect(service.formattedMetric(weight) == "75.5 킬로그램")
            #expect(service.formattedMetric(duration) == "1시간 1분 1초")
            let heartRate = HealthQueryMetric(id: "heartRate", title: "Heart Rate", value: 63, unit: .bpm)
            #expect(service.formattedMetric(heartRate) == "분당 63회")
        }
    }

    @Test("Speech announces each calendar date once and omits redundant workout dates")
    func spokenDatesDoNotRepeat() {
        let service = HealthQueryService()
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let metrics = [HealthQueryMetric(id: "weight", title: "Weight", value: 75, unit: .kilograms, date: date),
                       HealthQueryMetric(id: "fat", title: "Body Fat", value: 18, unit: .percent, date: date.addingTimeInterval(60))]
        let day = service.dateOnlyText(date)
        #expect(service.metricSummary(metrics).components(separatedBy: day).count == 2)
        #expect(!service.metricSummary(metrics, includeDates: false).contains(day))
    }

    @Test("Spoken calendar range excludes the following midnight")
    func spokenExclusiveEnd() throws {
        let service = HealthQueryService()
        let calendar = Calendar.current
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 1)))
        let end = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 1)))
        let text = service.periodText(DateInterval(start: start, end: end))
        #expect(text.contains(service.dateOnlyText(end.addingTimeInterval(-1))))
        #expect(!text.contains(service.dateOnlyText(end)))
    }

    @Test("Assistant fallback preserves the invoking locale through the query actor hop",
          .enabled(if: Bundle.main.localizations.contains("ko"), "Requires app localization resources"))
    func assistantFallbackLocale() async throws {
        let service = HealthQueryService(protectedDataProvider: { false })
        let assistant = HealthQueryAssistant(queryService: service, availabilityProvider: { false })
        let result = try await HealthQueryLocalization.$locale.withValue(Locale(identifier: "ko_KR")) {
            try await assistant.ask("최근 운동")
        }
        #expect(result.status == .locked)
        #expect(result.title == "최근 운동")
        #expect(result.spokenSummary == "건강 기록을 읽으려면 기기 잠금을 해제해 주세요.")
    }
}
