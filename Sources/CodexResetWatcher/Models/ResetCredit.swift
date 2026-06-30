import Foundation

struct ResetCreditsResponse: Decodable, Sendable {
    let credits: [ResetCredit]
    let availableCount: Int

    private enum CodingKeys: String, CodingKey {
        case credits
        case availableCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        credits = (try container.decodeIfPresent([FailableDecodable<ResetCredit>].self, forKey: .credits) ?? [])
            .compactMap(\.value)
        availableCount = container.decodeFlexibleIntIfPresent(forKey: .availableCount)
            ?? credits.filter(\.isAvailable).count
    }
}

struct ResetCredit: Decodable, Identifiable, Sendable {
    let id: String
    let resetType: String
    let status: String
    let grantedAt: String?
    let expiresAt: String?
    let redeemStartedAt: String?
    let redeemedAt: String?
    let title: String?
    let description: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case resetType
        case status
        case grantedAt
        case expiresAt
        case redeemStartedAt
        case redeemedAt
        case title
        case description
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleString(forKey: .id)
        resetType = try container.decodeFlexibleStringIfPresent(forKey: .resetType) ?? "unknown"
        status = try container.decodeFlexibleStringIfPresent(forKey: .status) ?? "unknown"
        grantedAt = try container.decodeFlexibleStringIfPresent(forKey: .grantedAt)
        expiresAt = try container.decodeFlexibleStringIfPresent(forKey: .expiresAt)
        redeemStartedAt = try container.decodeFlexibleStringIfPresent(forKey: .redeemStartedAt)
        redeemedAt = try container.decodeFlexibleStringIfPresent(forKey: .redeemedAt)
        title = try container.decodeFlexibleStringIfPresent(forKey: .title)
        description = try container.decodeFlexibleStringIfPresent(forKey: .description)
    }

    var isAvailable: Bool {
        status.caseInsensitiveCompare("available") == .orderedSame
    }
}

private struct FailableDecodable<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleString(forKey key: Key) throws -> String {
        if let value = try decodeFlexibleStringIfPresent(forKey: key) {
            return value
        }
        throw DecodingError.keyNotFound(
            key,
            DecodingError.Context(codingPath: codingPath, debugDescription: "Missing required string for \(key.stringValue)")
        )
    }

    func decodeFlexibleStringIfPresent(forKey key: Key) throws -> String? {
        guard contains(key) else {
            return nil
        }
        if try decodeNil(forKey: key) {
            return nil
        }
        if let value = try? decode(String.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return String(value)
        }
        return nil
    }
}
