import Foundation

struct SaveURLs: Sendable {
    let directory: URL
    let primary: URL
    let backup: URL
    let temporary: URL

    init(directory: URL) {
        self.directory = directory
        self.primary = directory.appendingPathComponent("save-v2.json", isDirectory: false)
        self.backup = directory.appendingPathComponent("save-v2.backup.json", isDirectory: false)
        self.temporary = directory.appendingPathComponent("save-v2.pending.json", isDirectory: false)
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

enum SaveLoadIssue: Equatable, Sendable {
    case unsupportedVersion(Int)
}

struct SaveLoadResult: Equatable, Sendable {
    let runState: RunState
    let source: SaveLoadSource
    let issue: SaveLoadIssue?

    init(
        runState: RunState,
        source: SaveLoadSource,
        issue: SaveLoadIssue? = nil
    ) {
        self.runState = runState
        self.source = source
        self.issue = issue
    }

    init(
        state: GameState,
        source: SaveLoadSource,
        issue: SaveLoadIssue? = nil
    ) {
        self.init(runState: .active(state), source: source, issue: issue)
    }

    var state: GameState {
        guard case let .active(state) = runState else {
            preconditionFailure("Class selection does not contain game state.")
        }
        return state
    }
}

protocol SaveStoring: Sendable {
    func load(newGame: GameState) async -> SaveLoadResult
    func save(_ state: GameState) async throws
    func load() async -> SaveLoadResult
    func save(_ runState: RunState) async throws
    func replaceRun(with runState: RunState) async throws
}

extension SaveStoring {
    func load() async -> SaveLoadResult {
        await load(newGame: .newGame(balance: .standard))
    }

    func save(_ runState: RunState) async throws {
        guard case let .active(state) = runState else { return }
        try await save(state)
    }

    func replaceRun(with runState: RunState) async throws {
        try await save(runState)
    }
}

protocol SaveFileSystem {
    func fileExists(at url: URL) -> Bool
    func createDirectory(at url: URL) throws
    func read(from url: URL) throws -> Data
    func write(_ data: Data, to url: URL, options: Data.WritingOptions) throws
    func moveItem(at source: URL, to destination: URL) throws
    func replaceItem(at destination: URL, with source: URL) throws
    func removeItem(at url: URL) throws
}

private struct FoundationSaveFileSystem: SaveFileSystem {
    let fileManager: FileManager

    func fileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    func createDirectory(at url: URL) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func read(from url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    func write(_ data: Data, to url: URL, options: Data.WritingOptions) throws {
        try data.write(to: url, options: options)
    }

    func moveItem(at source: URL, to destination: URL) throws {
        try fileManager.moveItem(at: source, to: destination)
    }

    func replaceItem(at destination: URL, with source: URL) throws {
        _ = try fileManager.replaceItemAt(destination, withItemAt: source)
    }

    func removeItem(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }
}

actor SaveStore: SaveStoring {
    private let urls: SaveURLs
    private let fileSystem: any SaveFileSystem
    private let codec: SaveCodec
    private let now: @Sendable () -> Date

    init(
        urls: SaveURLs = .applicationSupport,
        fileManager: FileManager = .default,
        codec: SaveCodec = SaveCodec(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.urls = urls
        self.fileSystem = FoundationSaveFileSystem(fileManager: fileManager)
        self.codec = codec
        self.now = now
    }

    init(
        urls: SaveURLs,
        fileSystem: any SaveFileSystem,
        codec: SaveCodec,
        now: @escaping @Sendable () -> Date
    ) {
        self.urls = urls
        self.fileSystem = fileSystem
        self.codec = codec
        self.now = now
    }

    func load() async -> SaveLoadResult {
        var issue: SaveLoadIssue?

        for (url, source) in [(urls.primary, SaveLoadSource.primary), (urls.backup, .backup)] {
            guard fileSystem.fileExists(at: url) else { continue }

            do {
                let document = try codec.decode(fileSystem.read(from: url))
                return SaveLoadResult(runState: document.runState, source: source, issue: issue)
            } catch {
                if case let SaveDecodingError.unsupportedVersion(version) = error {
                    issue = issue ?? .unsupportedVersion(version)
                }
                do {
                    try quarantine(url)
                } catch {
                    AppLog.persistence.error("Unable to quarantine save at \(url.path, privacy: .private(mask: .hash))")
                }
            }
        }

        return SaveLoadResult(runState: .classSelection, source: .newGame, issue: issue)
    }

    func load(newGame: GameState) async -> SaveLoadResult {
        let result = await load()
        guard result.runState == .classSelection, result.source == .newGame else { return result }
        return SaveLoadResult(runState: .active(newGame), source: .newGame, issue: result.issue)
    }

    func save(_ state: GameState) async throws {
        try await save(.active(state))
    }

    func save(_ runState: RunState) async throws {
        defer { try? removeIfPresent(urls.temporary) }

        do {
            try fileSystem.createDirectory(at: urls.directory)
            try removeIfPresent(urls.temporary)

            let data = try codec.encode(runState: runState, savedAt: now())
            try fileSystem.write(data, to: urls.temporary, options: .atomic)

            if fileSystem.fileExists(at: urls.primary) {
                if let primaryData = validatedSaveData(at: urls.primary) {
                    try installBackup(from: primaryData)
                } else {
                    try quarantine(urls.primary)
                }
            }
            try replace(urls.primary, with: urls.temporary)
        } catch {
            AppLog.persistence.error("Save failed at \(self.urls.directory.path, privacy: .private(mask: .hash))")
            throw error
        }
    }

    func replaceRun(with runState: RunState) async throws {
        defer { try? removeIfPresent(urls.temporary) }

        do {
            try fileSystem.createDirectory(at: urls.directory)
            try removeIfPresent(urls.temporary)
            let data = try codec.encode(runState: runState, savedAt: now())
            try fileSystem.write(data, to: urls.temporary, options: .atomic)
            let preservedBackup = urls.directory.appendingPathComponent(
                ".save-v2.replaced-backup-\(UUID().uuidString)",
                isDirectory: false
            )
            let hadBackup = fileSystem.fileExists(at: urls.backup)
            if hadBackup {
                try fileSystem.moveItem(at: urls.backup, to: preservedBackup)
            }
            do {
                try replace(urls.primary, with: urls.temporary)
            } catch {
                if hadBackup, !fileSystem.fileExists(at: urls.backup) {
                    try? fileSystem.moveItem(at: preservedBackup, to: urls.backup)
                }
                throw error
            }
            if hadBackup {
                try? removeIfPresent(preservedBackup)
            }
        } catch {
            AppLog.persistence.error("Run replacement failed at \(self.urls.directory.path, privacy: .private(mask: .hash))")
            throw error
        }
    }

    private func validatedSaveData(at url: URL) -> Data? {
        do {
            let data = try fileSystem.read(from: url)
            _ = try codec.decode(data)
            return data
        } catch {
            return nil
        }
    }

    private func installBackup(from primaryData: Data) throws {
        let stagedBackup = urls.directory.appendingPathComponent(
            ".save-v2.backup-\(UUID().uuidString).pending",
            isDirectory: false
        )
        defer { try? removeIfPresent(stagedBackup) }

        try fileSystem.write(primaryData, to: stagedBackup, options: .atomic)
        if fileSystem.fileExists(at: urls.backup) {
            guard validatedSaveData(at: urls.backup) != nil else {
                try quarantine(urls.backup)
                try fileSystem.moveItem(at: stagedBackup, to: urls.backup)
                return
            }
            try fileSystem.replaceItem(at: urls.backup, with: stagedBackup)
            return
        }
        try fileSystem.moveItem(at: stagedBackup, to: urls.backup)
    }

    private func replace(_ destination: URL, with source: URL) throws {
        if fileSystem.fileExists(at: destination) {
            try fileSystem.replaceItem(at: destination, with: source)
        } else {
            try fileSystem.moveItem(at: source, to: destination)
        }
    }

    private func removeIfPresent(_ url: URL) throws {
        guard fileSystem.fileExists(at: url) else { return }
        try fileSystem.removeItem(at: url)
    }

    private func quarantine(_ url: URL) throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let timestamp = formatter.string(from: now()).replacingOccurrences(of: ":", with: "-")
        let destination = url.deletingLastPathComponent().appendingPathComponent(
            "\(url.lastPathComponent).invalid-\(timestamp)-\(UUID().uuidString)",
            isDirectory: false
        )

        try fileSystem.moveItem(at: url, to: destination)
    }
}
