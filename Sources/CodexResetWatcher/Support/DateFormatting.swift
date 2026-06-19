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

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    static func compact(_ value: String?) -> String {
        guard let date = parse(value) else {
            return "-"
        }

        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d, h:mm a")
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    static func expiry(_ value: String?) -> String {
        guard let date = parse(value) else {
            return "-"
        }

        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d, yyyy h:mm a")
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    static func checked(_ date: Date?) -> String {
        guard let date else {
            return "Not checked yet"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.timeZone = .current
        return "Last checked \(formatter.string(from: date))"
    }

    static func resetTime(_ date: Date?) -> String {
        guard let date else {
            return "-"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    static func duration(seconds: Int?) -> String {
        guard let seconds else {
            return "-"
        }

        let clamped = max(0, seconds)
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
}
