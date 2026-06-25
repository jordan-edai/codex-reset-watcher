import Foundation

struct AccountSnapshotID: Codable, Hashable, Identifiable, RawRepresentable, Sendable {
    let rawValue: String

    var id: String {
        rawValue
    }

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

enum AccountSelection: Hashable, Identifiable, Sendable {
    case active
    case cached(AccountSnapshotID)

    var id: String {
        switch self {
        case .active:
            return "active"
        case let .cached(id):
            return "cached-\(id.rawValue)"
        }
    }
}
