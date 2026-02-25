import Foundation
import Testing
@testable import DUNE

@Suite("Number Formatting")
struct NumberFormattingTests {
    @Test("Int formattedWithSeparator adds thousand separators")
    func intFormatting() {
        #expect(4321.formattedWithSeparator == "4,321")
        #expect(12.formattedWithSeparator == "12")
    }

    @Test("Double formattedWithSeparator keeps fraction digits with grouping")
    func doubleFormatting() {
        #expect(4321.0.formattedWithSeparator() == "4,321")
        #expect(4321.56.formattedWithSeparator(fractionDigits: 1) == "4,321.6")
        #expect(4321.56.formattedWithSeparator(fractionDigits: 2) == "4,321.56")
    }

    @Test("Double formattedWithSeparator supports explicit positive sign")
    func signedFormatting() {
        #expect(4321.5.formattedWithSeparator(fractionDigits: 1, alwaysShowSign: true) == "+4,321.5")
        #expect((-4321.5).formattedWithSeparator(fractionDigits: 1, alwaysShowSign: true) == "-4,321.5")
    }
}
