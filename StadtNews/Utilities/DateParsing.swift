import Foundation

enum DateParsing {
    /// Parser for RSS `pubDate` values, e.g. "Tue, 26 May 2026 18:18:54 +0200".
    static let rfc2822: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter
    }()
}

extension Date {
    /// Editorial-style relative label: "vor 5 Min.", "vor 3 Std.", or an
    /// absolute date for older items.
    func newsRelativeDescription(relativeTo now: Date = Date()) -> String {
        let seconds = now.timeIntervalSince(self)

        if seconds < 60 { return "gerade eben" }
        if seconds < 3_600 {
            return "vor \(Int(seconds / 60)) Min."
        }
        if seconds < 86_400 {
            return "vor \(Int(seconds / 3_600)) Std."
        }
        if seconds < 7 * 86_400 {
            let days = Int(seconds / 86_400)
            return days == 1 ? "Gestern" : "vor \(days) Tagen"
        }

        return Self.absoluteFormatter.string(from: self)
    }

    /// "26. Mai 2026, 18:18 Uhr" – used in the article detail byline.
    func newsAbsoluteDescription() -> String {
        Self.bylineFormatter.string(from: self)
    }

    private static let absoluteFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
        formatter.setLocalizedDateFormatFromTemplate("ddMMMyyyy")
        return formatter
    }()

    private static let bylineFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
        formatter.dateFormat = "d. MMMM yyyy, HH:mm 'Uhr'"
        return formatter
    }()
}
