import Foundation
import XCTest
@testable import DockBarHero

final class SettingsStoreTests: XCTestCase {
    private var directory: URL!
    private let now = Date(timeIntervalSince1970: 1_783_641_600)

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DockBarHero-SettingsStore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        try super.tearDownWithError()
    }

    func testURLsUseSettingsSpecificVersionedNames() {
        let urls = SettingsURLs(directory: directory)

        XCTAssertEqual(urls.primary.lastPathComponent, "settings-v1.json")
        XCTAssertEqual(urls.backup.lastPathComponent, "settings-v1.backup.json")
        XCTAssertEqual(urls.temporary.lastPathComponent, "settings-v1.pending.json")
        XCTAssertNotEqual(urls.primary, SaveURLs(directory: directory).primary)
    }

    func testMissingFileLoadsDefaults() async {
        let loaded = await makeStore().load()
        XCTAssertEqual(loaded, .defaults)
    }

    func testRoundTripUsesDeterministicSortedJSON() async throws {
        let settings = AppSettings(
            schemaVersion: 1,
            manualVisibility: .hidden,
            animationMode: .paused,
            inputMode: .interactive
        )
        let store = makeStore()

        try await store.save(settings)
        let first = try Data(contentsOf: SettingsURLs(directory: directory).primary)
        try await store.save(settings)
        let second = try Data(contentsOf: SettingsURLs(directory: directory).primary)

        let loaded = await store.load()
        XCTAssertEqual(loaded, settings)
        XCTAssertEqual(first, second)
        XCTAssertEqual(
            String(decoding: first, as: UTF8.self),
            #"{"animationMode":"paused","inputMode":"interactive","manualVisibility":"hidden","schemaVersion":1}"#
        )
    }

    func testSecondSaveAtomicallyReplacesPrimaryAndPreservesBackup() async throws {
        let store = makeStore()
        let first = AppSettings.defaults
        var second = first
        second.manualVisibility = .hidden

        try await store.save(first)
        try await store.save(second)

        let urls = SettingsURLs(directory: directory)
        XCTAssertEqual(try decode(urls.primary), second)
        XCTAssertEqual(try decode(urls.backup), first)
        XCTAssertFalse(FileManager.default.fileExists(atPath: urls.temporary.path))
    }

    func testCorruptSettingsAreQuarantinedAndDefaultsAreLoaded() async throws {
        let urls = SettingsURLs(directory: directory)
        let corrupt = Data("not-json".utf8)
        try corrupt.write(to: urls.primary)

        let loaded = await makeStore().load()

        XCTAssertEqual(loaded, .defaults)
        XCTAssertFalse(FileManager.default.fileExists(atPath: urls.primary.path))
        let quarantine = try XCTUnwrap(
            FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .first { $0.lastPathComponent.contains("settings-v1.json.invalid-") }
        )
        XCTAssertEqual(try Data(contentsOf: quarantine), corrupt)
    }

    func testUnsupportedSettingsVersionIsQuarantinedAndDefaultsAreLoaded() async throws {
        let urls = SettingsURLs(directory: directory)
        let future = Data(
            #"{"animationMode":"running","inputMode":"passive","manualVisibility":"shown","schemaVersion":2}"#.utf8
        )
        try future.write(to: urls.primary)

        let loaded = await makeStore().load()
        XCTAssertEqual(loaded, .defaults)
        XCTAssertFalse(FileManager.default.fileExists(atPath: urls.primary.path))
    }

    func testSettingsRecoveryNeverMutatesGameSaveFiles() async throws {
        let saveURLs = SaveURLs(directory: directory)
        let fixtures: [(URL, Data)] = [
            (saveURLs.primary, Data("primary-save".utf8)),
            (saveURLs.backup, Data("backup-save".utf8)),
            (saveURLs.temporary, Data("pending-save".utf8)),
        ]
        for (url, data) in fixtures {
            try data.write(to: url)
        }
        try Data("corrupt-settings".utf8).write(to: SettingsURLs(directory: directory).primary)
        let store = makeStore()

        _ = await store.load()
        try await store.save(.defaults)

        for (url, data) in fixtures {
            XCTAssertEqual(try Data(contentsOf: url), data)
        }
    }

    private func makeStore() -> SettingsStore {
        SettingsStore(urls: SettingsURLs(directory: directory), now: { [now] in now })
    }

    private func decode(_ url: URL) throws -> AppSettings {
        try JSONDecoder().decode(AppSettings.self, from: Data(contentsOf: url))
    }
}
