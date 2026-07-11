import Foundation

struct SaveURLs: Sendable {
    let directory: URL
    let primary: URL
    let backup: URL
    let temporary: URL

    init(directory: URL) {
        self.directory = directory
        self.primary = directory.appendingPathComponent("save-v1.json", isDirectory: false)
        self.backup = directory.appendingPathComponent("save-v1.backup.json", isDirectory: false)
        self.temporary = directory.appendingPathComponent("save-v1.pending.json", isDirectory: false)
    }

    static var applicationSupport: SaveURLs {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.n3kr0nom1c0n.DockBarHero", isDirectory: true)
        return SaveURLs(directory: directory)
    }
}

enum SaveLoadSource: Equatable, Sendable {
    case primary
    case backup
    case newGame
}

struct SaveLoadResult: Equatable, Sendable {
    let state: GameState
    let source: SaveLoadSource
}

protocol SaveStoring: Sendable {
    func load(newGame: GameState) async -> SaveLoadResult
    func save(_ state: GameState) async throws
}

actor SaveStore: SaveStoring {
    private let urls: SaveURLs
    private let fileManager: FileManager
    private let codec: SaveCodec
    private let now: @Sendable () -> Date

    init(
        urls: SaveURLs = .applicationSupport,
        fileManager: FileManager = .default,
        codec: SaveCodec = SaveCodec(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.urls = urls
        self.fileManager = fileManager
        self.codec = codec
        self.now = now
    }

    func load(newGame: GameState) async -> SaveLoadResult {
        for (url, source) in [(urls.primary, SaveLoadSource.primary), (urls.backup, .backup)] {
            guard fileManager.fileExists(atPath: url.path) else { continue }

            do {
                let document = try codec.decode(Data(contentsOf: url))
                return SaveLoadResult(state: document.state, source: source)
            } catch {
                quarantine(url)
            }
        }

        return SaveLoadResult(state: newGame, source: .newGame)
    }

    func save(_ state: GameState) async throws {
        defer { try? removeIfPresent(urls.temporary) }

        do {
            try fileManager.createDirectory(at: urls.directory, withIntermediateDirectories: true)
            try removeIfPresent(urls.temporary)

            let data = try codec.encode(state: state, savedAt: now())
            try data.write(to: urls.temporary, options: .atomic)

            if fileManager.fileExists(atPath: urls.primary.path) {
                try stageBackupFromPrimary()
                try replace(urls.primary, with: urls.temporary)
            } else {
                try fileManager.moveItem(at: urls.temporary, to: urls.primary)
            }
        } catch {
            AppLog.persistence.error("Save failed at \(self.urls.directory.path, privacy: .private(mask: .hash))")
            throw error
        }
    }

    private func stageBackupFromPrimary() throws {
        let stagedBackup = urls.directory.appendingPathComponent(
            ".save-v1.backup-\(UUID().uuidString).pending",
            isDirectory: false
        )
        defer { try? removeIfPresent(stagedBackup) }

        try fileManager.copyItem(at: urls.primary, to: stagedBackup)
        if fileManager.fileExists(atPath: urls.backup.path) {
            try replace(urls.backup, with: stagedBackup)
        } else {
            try fileManager.moveItem(at: stagedBackup, to: urls.backup)
        }
    }

    private func replace(_ destination: URL, with source: URL) throws {
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: source)
        } else {
            try fileManager.moveItem(at: source, to: destination)
        }
    }

    private func removeIfPresent(_ url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    private func quarantine(_ url: URL) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let timestamp = formatter.string(from: now()).replacingOccurrences(of: ":", with: "-")
        let destination = url.deletingLastPathComponent().appendingPathComponent(
            "\(url.lastPathComponent).invalid-\(timestamp)-\(UUID().uuidString)",
            isDirectory: false
        )

        do {
            try fileManager.moveItem(at: url, to: destination)
        } catch {
            AppLog.persistence.error("Unable to quarantine save at \(url.path, privacy: .private(mask: .hash))")
        }
    }
}
