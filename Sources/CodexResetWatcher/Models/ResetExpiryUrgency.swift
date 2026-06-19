import Foundation

struct ResetExpiryUrgency: Equatable, Sendable {
    enum Level: Equatable, Sendable {
        case normal
        case approaching
        case soon
        case urgent
        case expired
        case inactive
        case unknown
    }

    let level: Level
    let badge: String
    let hint: String?

    static func make(expiresAt: Date?, now: Date = Date(), isAvailable: Bool) -> ResetExpiryUrgency {
        guard isAvailable else {
            return ResetExpiryUrgency(level: .inactive, badge: "Used", hint: nil)
        }

        guard let expiresAt else {
            return ResetExpiryUrgency(level: .unknown, badge: "Available", hint: "Expiry unknown")
        }

        let seconds = expiresAt.timeIntervalSince(now)

        if seconds <= 0 {
            return ResetExpiryUrgency(level: .expired, badge: "Expired", hint: "This reset is past its expiry time")
        }

        if seconds <= 86_400 {
            return ResetExpiryUrgency(level: .urgent, badge: "Ends today", hint: "Use it soon or let it go")
        }

        if seconds <= 3 * 86_400 {
            return ResetExpiryUrgency(level: .soon, badge: "Expires soon", hint: "Worth keeping top of mind")
        }

        if seconds <= 7 * 86_400 {
            return ResetExpiryUrgency(level: .approaching, badge: "This week", hint: "Expiry is getting closer")
        }

        return ResetExpiryUrgency(level: .normal, badge: "Available", hint: nil)
    }
}
