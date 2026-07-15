import Foundation

struct SettingsURLs: Sendable {
    let directory: URL
    let primary: URL
    let backup: URL
    let temporary: URL
    let legacyV1Primary: URL
    let legacyV1Backup: URL

    init(directory: URL) {
        self.directory = directory
        self.primary = directory.appendingPathComponent("settings-v2.json", isDirectory: false)
        self.backup = directory.appendingPathComponent("settings-v2.backup.json", isDirectory: false)
        self.temporary = directory.appendingPathComponent("settings-v2.pending.json", isDirectory: false)
        self.legacyV1Primary = directory.appendingPathComponent("settings-v1.json", isDirectory: false)
        self.legacyV1Backup = directory.appendingPathComponent("settings-v1.backup.json", isDirectory: false)
    }

    static var applicationSupport: SettingsURLs {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.n3kr0nom1c0n.DockBarHero", isDirectory: true)
        return SettingsURLs(directory: directory)
    }
}

protocol SettingsStoring: Sendable {
    func load() async -> AppSettings
    func save(_ settings: AppSettings) async throws
}

actor SettingsStore: SettingsStoring {
    private let urls: SettingsURLs
    private let fileManager: FileManager
    private let codec: SettingsCodec
    private let now: @Sendable () -> Date

    init(
        urls: SettingsURLs = .applicationSupport,
        fileManager: FileManager = .default,
        codec: SettingsCodec = SettingsCodec(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.urls = urls
        self.fileManager = fileManager
        self.codec = codec
        self.now = now
    }

    func load() async -> AppSettings {
        for url in [urls.primary, urls.backup, urls.legacyV1Primary, urls.legacyV1Backup] {
            guard fileManager.fileExists(atPath: url.path) else { continue }
            do {
                let settings = try codec.decode(Data(contentsOf: url))
                if url == urls.legacyV1Primary || url == urls.legacyV1Backup {
                    do {
                        try await save(settings)
                    } catch {
                        AppLog.persistence.error("Unable to persist migrated settings")
                    }
                }
                return settings
            } catch {
                do {
                    try quarantine(url)
                } catch {
                    AppLog.persistence.error("Unable to quarantine settings at \(url.path, privacy: .private(mask: .hash))")
                }
            }
        }
        return .defaults
    }

    func save(_ settings: AppSettings) async throws {
        defer { try? removeIfPresent(urls.temporary) }

        do {
            try fileManager.createDirectory(at: urls.directory, withIntermediateDirectories: true)
            try removeIfPresent(urls.temporary)
            try codec.encode(settings).write(to: urls.temporary, options: .atomic)

            if fileManager.fileExists(atPath: urls.primary.path) {
                if let primaryData = validatedData(at: urls.primary) {
                    try installBackup(from: primaryData)
                } else {
                    try quarantine(urls.primary)
                }
            }
            try replace(urls.primary, with: urls.temporary)
        } catch {
            AppLog.persistence.error("Settings save failed at \(self.urls.directory.path, privacy: .private(mask: .hash))")
            throw error
        }
    }

    private func validatedData(at url: URL) -> Data? {
        guard let data = try? Data(contentsOf: url),
              (try? codec.decode(data)) != nil else {
            return nil
        }
        return data
    }

    private func installBackup(from primaryData: Data) throws {
        let staged = urls.directory.appendingPathComponent(
            ".settings-v2.backup-\(UUID().uuidString).pending",
            isDirectory: false
        )
        defer { try? removeIfPresent(staged) }

        try primaryData.write(to: staged, options: .atomic)
        if fileManager.fileExists(atPath: urls.backup.path) {
            if validatedData(at: urls.backup) == nil {
                try quarantine(urls.backup)
                try fileManager.moveItem(at: staged, to: urls.backup)
            } else {
                _ = try fileManager.replaceItemAt(urls.backup, withItemAt: staged)
            }
        } else {
            try fileManager.moveItem(at: staged, to: urls.backup)
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

    private func quarantine(_ url: URL) throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let timestamp = formatter.string(from: now()).replacingOccurrences(of: ":", with: "-")
        let destination = url.deletingLastPathComponent().appendingPathComponent(
            "\(url.lastPathComponent).invalid-\(timestamp)-\(UUID().uuidString)",
            isDirectory: false
        )
        try fileManager.moveItem(at: url, to: destination)
    }
}
