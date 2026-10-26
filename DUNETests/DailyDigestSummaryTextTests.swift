import Foundation
import Testing
@testable import DUNE

@Suite("DailyDigestSummaryText")
struct DailyDigestSummaryTextTests {
    @Test("English preview keeps only the first complete sentence")
    func englishFirstSentence() {
        let text = DailyDigestSummaryText("  Your condition improved today. You walked 9,800 steps.  ")

        #expect(text.full == "Your condition improved today. You walked 9,800 steps.")
        #expect(text.preview == "Your condition improved today.")
        #expect(text.canExpand)
    }

    @Test("Korean preview keeps the first complete sentence")
    func koreanFirstSentence() {
        let text = DailyDigestSummaryText("오늘은 컨디션이 좋습니다. 내일도 유지하세요.")

        #expect(text.preview == "오늘은 컨디션이 좋습니다.")
        #expect(text.canExpand)
    }

    @Test("Japanese preview recognizes the sentence terminator")
    func japaneseFirstSentence() {
        let text = DailyDigestSummaryText("今日はよく眠れました。運動もできました。")

        #expect(text.preview == "今日はよく眠れました。")
        #expect(text.canExpand)
    }

    @Test("Decimal point stays inside the first sentence")
    func decimalPoint() {
        let text = DailyDigestSummaryText("The score rose 2.5 points. Recovery remains steady.")

        #expect(text.preview == "The score rose 2.5 points.")
        #expect(text.canExpand)
    }

    @Test("Empty and whitespace-only summaries remain nonexpandable", arguments: ["", "  \n\t  "])
    func emptyOrWhitespace(summary: String) {
        let text = DailyDigestSummaryText(summary)

        #expect(text.full.isEmpty)
        #expect(text.preview.isEmpty)
        #expect(!text.canExpand)
    }

    @Test("A single sentence does not expose expansion")
    func singleSentence() {
        let text = DailyDigestSummaryText("Today's records are ready.")

        #expect(text.preview == text.full)
        #expect(!text.canExpand)
    }

    @Test("Text without sentence punctuation remains whole")
    func noPunctuation() {
        let text = DailyDigestSummaryText("  Today's records are ready  ")

        #expect(text.full == "Today's records are ready")
        #expect(text.preview == text.full)
        #expect(!text.canExpand)
    }
}
