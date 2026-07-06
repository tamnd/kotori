import Foundation

/// Number and date formatting the way X renders them.
public enum Format {
    /// 999 -> "999", 1234 -> "1.2K", 12345 -> "12.3K", 1200000 -> "1.2M".
    /// X drops the decimal once it would read ".0": 2000 -> "2K".
    public static func count(_ n: Int) -> String {
        let sign = n < 0 ? "-" : ""
        let v = abs(n)
        switch v {
        case ..<1000:
            return "\(sign)\(v)"
        case ..<1_000_000:
            return sign + scaled(v, by: 1000, suffix: "K")
        case ..<1_000_000_000:
            return sign + scaled(v, by: 1_000_000, suffix: "M")
        default:
            return sign + scaled(v, by: 1_000_000_000, suffix: "B")
        }
    }

    private static func scaled(_ v: Int, by unit: Int, suffix: String) -> String {
        // One decimal, truncated not rounded, so 1999 reads 1.9K like on X.
        let tenths = v * 10 / unit
        if tenths % 10 == 0 {
            return "\(tenths / 10)\(suffix)"
        }
        return "\(tenths / 10).\(tenths % 10)\(suffix)"
    }

    /// Compact timeline stamp: "now", "45s", "12m", "3h", then "Mar 5",
    /// then "Mar 5, 2024" once the year differs.
    public static func relativeStamp(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 5 { return "now" }
        if seconds < 60 { return "\(Int(seconds))s" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        if seconds < 86400 { return "\(Int(seconds / 3600))h" }

        let f = DateFormatter()
        f.calendar = calendar
        f.locale = Locale(identifier: "en_US_POSIX")
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        f.dateFormat = sameYear ? "MMM d" : "MMM d, yyyy"
        return f.string(from: date)
    }

    /// Video duration pill: "0:07", "1:32", "1:02:03".
    public static func duration(milliseconds: Int) -> String {
        let total = milliseconds / 1000
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}
