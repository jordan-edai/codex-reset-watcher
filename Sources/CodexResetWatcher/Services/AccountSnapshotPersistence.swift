import CryptoKit
import Foundation

struct AccountSnapshotPersistence {
    private struct SnapshotFile: Codable {
        let schemaVersion: Int
        var snapshots: [CodexAccountSnapshot]
    }

    private static let schemaVersion = 1
    private static let appSupportFolderName = "Codex Reset Watcher"
    private static let snapshotFilename = "account-snapshots.json"
    private static let saltFilename = "install-salt.txt"

    let fileURL: URL
    private let saltURL: URL?
    private let fixedSalt: String?
    private let fileManager: FileManager

    init(
        fileURL: URL? = nil,
        salt: String? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        if let fileURL {
            self.fileURL = fileURL
            saltURL = nil
            fixedSalt = salt
        } else {
            let directory = Self.defaultDirectory(fileManager: fileManager)
            self.fileURL = directory.appending(path: Self.snapshotFilename)
            saltURL = directory.appending(path: Self.saltFilename)
            fixedSalt = salt
        }
    }

    func load() -> [CodexAccountSnapshot] {
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL)
        else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let file = try? decoder.decode(SnapshotFile.self, from: data),
              file.schemaVersion == Self.schemaVersion
        else {
            return []
        }

        return file.snapshots.filter { $0.schemaVersion == CodexAccountSnapshot.currentSchemaVersion }
    }

    func save(_ snapshots: [CodexAccountSnapshot]) throws {
        try createParentDirectory()

        let file = SnapshotFile(
            schemaVersion: Self.schemaVersion,
            snapshots: snapshots.sorted { $0.lastChecked > $1.lastChecked }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(file)
        try data.write(to: fileURL, options: [.atomic])
        try setPrivateFilePermissions(fileURL)
    }

    func upsert(_ snapshot: CodexAccountSnapshot, into snapshots: [CodexAccountSnapshot]) throws -> [CodexAccountSnapshot] {
        var next = snapshots.filter { $0.id != snapshot.id }
        next.append(snapshot)
        try save(next)
        return next.sorted { $0.lastChecked > $1.lastChecked }
    }

    func delete(id: AccountSnapshotID, from snapshots: [CodexAccountSnapshot]) throws -> [CodexAccountSnapshot] {
        let next = snapshots.filter { $0.id != id }
        try save(next)
        return next
    }

    func clear(_ snapshots: [CodexAccountSnapshot]) throws -> [CodexAccountSnapshot] {
        try save([])
        return []
    }

    func snapshotID(for accountID: String) throws -> AccountSnapshotID {
        let cleanID = accountID.trimmingCharacters(in: .whitespacesAndNewlines)
        let salt = try loadSalt()
        let input = "\(salt):\(cleanID)"
        let digest = SHA256.hash(data: Data(input.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return AccountSnapshotID(rawValue: String(hex.prefix(32)))
    }

    private static func defaultDirectory(fileManager: FileManager) -> URL {
        if let url = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return url.appending(path: appSupportFolderName, directoryHint: .isDirectory)
        }
        return fileManager.homeDirectoryForCurrentUser
            .appending(path: "Library", directoryHint: .isDirectory)
            .appending(path: "Application Support", directoryHint: .isDirectory)
            .appending(path: appSupportFolderName, directoryHint: .isDirectory)
    }

    private func createParentDirectory() throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try? fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
    }

    private func loadSalt() throws -> String {
        if let fixedSalt {
            return fixedSalt
        }

        guard let saltURL else {
            return "codex-reset-watcher-test-salt"
        }

        try createParentDirectory()

        if fileManager.fileExists(atPath: saltURL.path),
           let value = try? String(contentsOf: saltURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           !value.isEmpty {
            return value
        }

        let bytes = (0..<32).map { _ in UInt8.random(in: UInt8.min...UInt8.max) }
        let salt = Data(bytes).base64EncodedString()
        try salt.write(to: saltURL, atomically: true, encoding: .utf8)
        try setPrivateFilePermissions(saltURL)
        return salt
    }

    private func setPrivateFilePermissions(_ url: URL) throws {
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
