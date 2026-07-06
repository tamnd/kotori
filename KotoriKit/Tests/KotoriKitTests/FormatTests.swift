import Foundation
import Testing
@testable import KotoriKit

@Suite("Count formatting")
struct CountFormatTests {
    @Test func smallNumbersPassThrough() {
        #expect(Format.count(0) == "0")
        #expect(Format.count(7) == "7")
        #expect(Format.count(999) == "999")
    }

    @Test func thousandsTruncateToOneDecimal() {
        #expect(Format.count(1000) == "1K")
        #expect(Format.count(1234) == "1.2K")
        #expect(Format.count(1999) == "1.9K")
        #expect(Format.count(12345) == "12.3K")
        #expect(Format.count(999_999) == "999.9K")
    }

    @Test func millionsAndBillions() {
        #expect(Format.count(1_200_000) == "1.2M")
        #expect(Format.count(34_000_000) == "34M")
        #expect(Format.count(2_500_000_000) == "2.5B")
    }

    @Test func negativeKeepsSign() {
        #expect(Format.count(-1234) == "-1.2K")
    }
}

@Suite("Relative stamps")
struct RelativeStampTests {
    let now = Date(timeIntervalSince1970: 1_751_800_000) // 2025-07-06 in UTC

    var utcCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    @Test func recentUnits() {
        #expect(Format.relativeStamp(now.addingTimeInterval(-2), now: now, calendar: utcCalendar) == "now")
        #expect(Format.relativeStamp(now.addingTimeInterval(-45), now: now, calendar: utcCalendar) == "45s")
        #expect(Format.relativeStamp(now.addingTimeInterval(-12 * 60), now: now, calendar: utcCalendar) == "12m")
        #expect(Format.relativeStamp(now.addingTimeInterval(-3 * 3600), now: now, calendar: utcCalendar) == "3h")
    }

    @Test func olderFallsToDates() {
        let sameYear = Format.relativeStamp(now.addingTimeInterval(-40 * 86400), now: now, calendar: utcCalendar)
        #expect(!sameYear.contains(","))
        let otherYear = Format.relativeStamp(now.addingTimeInterval(-400 * 86400), now: now, calendar: utcCalendar)
        #expect(otherYear.contains("2024"))
    }
}

@Suite("Durations")
struct DurationTests {
    @Test func pillFormats() {
        #expect(Format.duration(milliseconds: 7_000) == "0:07")
        #expect(Format.duration(milliseconds: 92_000) == "1:32")
        #expect(Format.duration(milliseconds: 3_723_000) == "1:02:03")
    }
}
