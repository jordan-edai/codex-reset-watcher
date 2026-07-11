import Foundation

@MainActor
enum DateFormatting {
    private static let fractionalParser: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let standardParser: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fullFormatter = styleFormatter(date: .medium, time: .short)
    private static let compactFormatter = templateFormatter("MMM d j:mm")
    private static let weekdayCompactFormatter = templateFormatter("EEE MMM d j:mm")
    private static let weekdayDateFormatter = templateFormatter("EEE MMMd")
    private static let weekdayNameFormatter = templateFormatter("EEEE")
    private static let timeOnlyFormatter = templateFormatter("jm")
    private static let expiryFormatter = templateFormatter("MMM d yyyy j:mm")

    static func parse(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else {
            return nil
        }
        return fractionalParser.date(from: value) ?? standardParser.date(from: value)
    }

    static func full(_ value: String?) -> String {
        guard let date = parse(value) else {
            return "-"
        }

        return displayString(fullFormatter, date: date)
    }

    static func compact(_ value: String?) -> String {
        compact(parse(value))
    }

    static func compact(_ date: Date?) -> String {
        guard let date else {
            return "-"
        }

        return displayString(compactFormatter, date: date)
    }

    static func weekdayCompact(_ value: String?) -> String {
        weekdayCompact(parse(value))
    }

    static func weekdayCompact(_ date: Date?) -> String {
        guard let date else {
            return "-"
        }

        return displayString(weekdayCompactFormatter, date: date)
    }

    static func weekdayDate(_ value: String?) -> String {
        weekdayDate(parse(value))
    }

    static func weekdayDate(_ date: Date?) -> String {
        guard let date else {
            return "-"
        }

        return displayString(weekdayDateFormatter, date: date)
    }

    static func weekdayName(_ date: Date?) -> String {
        guard let date else {
            return "-"
        }

        return displayString(weekdayNameFormatter, date: date)
    }

    static func timeOnly(_ value: String?) -> String {
        timeOnly(parse(value))
    }

    static func timeOnly(_ date: Date?) -> String {
        guard let date else {
            return "-"
        }

        return displayString(timeOnlyFormatter, date: date)
    }

    static func expiry(_ value: String?) -> String {
        guard let date = parse(value) else {
            return "-"
        }

        return displayString(expiryFormatter, date: date)
    }

    static func checked(_ date: Date?) -> String {
        guard let date else {
            return "Not checked yet"
        }

        return "Last checked \(displayString(timeOnlyFormatter, date: date))"
    }

    static func resetTime(_ date: Date?) -> String {
        guard let date else {
            return "-"
        }

        return displayString(fullFormatter, date: date)
    }

    static func duration(seconds: Int?) -> String {
        guard let seconds else {
            return "-"
        }

        let clamped = max(0, seconds)
        if clamped == 0 {
            return "now"
        }
        let days = clamped / 86_400
        let hours = (clamped % 86_400) / 3_600
        let minutes = (clamped % 3_600) / 60

        if days > 0 {
            return hours > 0 ? "\(days)d \(hours)h" : "\(days)d"
        }
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(max(1, minutes))m"
    }

    static func windowTitle(seconds: Int) -> String {
        if seconds >= 86_400 {
            let days = max(1, seconds / 86_400)
            return "\(days)d limit"
        }
        let hours = max(1, seconds / 3_600)
        return "\(hours)h limit"
    }

    private static func templateFormatter(_ template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.calendar = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    private static func styleFormatter(date: DateFormatter.Style, time: DateFormatter.Style) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.calendar = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateStyle = date
        formatter.timeStyle = time
        return formatter
    }

    private static func displayString(_ formatter: DateFormatter, date: Date) -> String {
        formatter.string(from: date)
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
    }
}
