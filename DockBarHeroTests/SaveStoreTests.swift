import Foundation
import XCTest
@testable import DockBarHero

final class SaveStoreTests: XCTestCase {
    private var directory: URL!
    private let savedAt = Date(timeIntervalSince1970: 1_783_641_600)

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DockBarHero-SaveStore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        try super.tearDownWithError()
    }

    func testSaveURLsUseVersionedNames() {
        let urls = SaveURLs(directory: directory)

        XCTAssertEqual(urls.primary.lastPathComponent, "save-v1.json")
        XCTAssertEqual(urls.backup.lastPathComponent, "save-v1.backup.json")
        XCTAssertEqual(urls.temporary.lastPathComponent, "save-v1.pending.json")
    }

    func testApplicationSupportURLsUseDockBarHeroDirectory() {
        let urls = SaveURLs.applicationSupport

        XCTAssertEqual(urls.directory.lastPathComponent, "com.n3kr0nom1c0n.DockBarHero")
        XCTAssertEqual(urls.directory.deletingLastPathComponent().lastPathComponent, "Application Support")
    }

    func testFirstSaveCreatesPrimaryAndLeavesNoPendingFile() async throws {
        let store = makeStore()
        let state = GameState.newGame(balance: .standard)

        try await store.save(state)

        let urls = SaveURLs(directory: directory)
        XCTAssertTrue(FileManager.default.fileExists(atPath: urls.primary.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: urls.backup.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: urls.temporary.path))
        XCTAssertEqual(try SaveCodec().decode(Data(contentsOf: urls.primary)).state, state)
    }

    func testSecondSavePreservesPriorPrimaryAsBackup() async throws {
        let store = makeStore()
        let first = GameState.newGame(balance: .standard)
        var second = first
        second.autoEquipEnabled = false

        try await store.save(first)
        try await store.save(second)

        let urls = SaveURLs(directory: directory)
        XCTAssertEqual(try SaveCodec().decode(Data(contentsOf: urls.primary)).state, second)
        XCTAssertEqual(try SaveCodec().decode(Data(contentsOf: urls.backup)).state, first)
    }

    func testLoadReturnsPrimaryWhenPrimaryIsValid() async throws {
        let store = makeStore()
        let state = GameState.newGame(balance: .standard)
        try await store.save(state)

        let result = await store.load(newGame: stateWithAutoEquip(false))

        XCTAssertEqual(result, SaveLoadResult(state: state, source: .primary))
    }

    func testCorruptPrimaryLoadsBackupAndQuarantinesPrimary() async throws {
        let store = makeStore()
        let first = GameState.newGame(balance: .standard)
        var second = first
        second.autoEquipEnabled = false
        try await store.save(first)
        try await store.save(second)

        let urls = SaveURLs(directory: directory)
        let corruptData = Data("not-json".utf8)
        try corruptData.write(to: urls.primary)

        let result = await store.load(newGame: stateWithAutoEquip(true))

        XCTAssertEqual(result, SaveLoadResult(state: first, source: .backup))
        let quarantined = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.contains("save-v1.json.invalid-") }
        XCTAssertEqual(quarantined.count, 1)
        XCTAssertTrue(quarantined[0].lastPathComponent.contains(".invalid-2026-07-10T00-00-00Z-"))
        XCTAssertEqual(try Data(contentsOf: quarantined[0]), corruptData)
    }

    func testBothInvalidFilesStartNewGameAndPreserveDiagnostics() async throws {
        let store = makeStore()
        let urls = SaveURLs(directory: directory)
        let primaryData = Data("bad-primary".utf8)
        let backupData = Data("bad-backup".utf8)
        try primaryData.write(to: urls.primary)
        try backupData.write(to: urls.backup)

        let newGame = stateWithAutoEquip(false)
        let result = await store.load(newGame: newGame)

        XCTAssertEqual(result, SaveLoadResult(state: newGame, source: .newGame))
        let quarantined = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.contains(".invalid-") }
        XCTAssertEqual(quarantined.count, 2)
        XCTAssertTrue(quarantined.contains { (try? Data(contentsOf: $0)) == primaryData })
        XCTAssertTrue(quarantined.contains { (try? Data(contentsOf: $0)) == backupData })
    }

    func testUnsupportedFuturePrimaryFallsBackToValidBackupAndPreservesPrimary() async throws {
        let store = makeStore()
        let backupState = GameState.newGame(balance: .standard)
        let urls = SaveURLs(directory: directory)
        try SaveCodec().encode(state: backupState, savedAt: savedAt).write(to: urls.backup)
        let futureData = Data(#"{"schemaVersion":99,"savedAt":"2026-07-10T00:00:00Z","state":{}}"#.utf8)
        try futureData.write(to: urls.primary)

        let result = await store.load(newGame: stateWithAutoEquip(false))

        XCTAssertEqual(result, SaveLoadResult(state: backupState, source: .backup))
        let quarantined = try XCTUnwrap(try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).first { $0.lastPathComponent.contains(".invalid-") })
        XCTAssertEqual(try Data(contentsOf: quarantined), futureData)
    }

    func testStalePendingIsCleanedBeforeSave() async throws {
        let store = makeStore()
        let urls = SaveURLs(directory: directory)
        try Data("stale".utf8).write(to: urls.temporary)

        try await store.save(GameState.newGame(balance: .standard))

        XCTAssertFalse(FileManager.default.fileExists(atPath: urls.temporary.path))
    }

    func testFailedSavePreservesExistingPrimaryAndBackupAndCleansPending() async throws {
        let store = makeStore()
        let first = GameState.newGame(balance: .standard)
        var second = first
        second.autoEquipEnabled = false
        try await store.save(first)
        try await store.save(second)

        let urls = SaveURLs(directory: directory)
        let primaryBefore = try Data(contentsOf: urls.primary)
        let backupBefore = try Data(contentsOf: urls.backup)
        var invalid = second
        invalid.hero.currentHealth = 0

        await XCTAssertThrowsErrorAsync(try await store.save(invalid))

        XCTAssertEqual(try Data(contentsOf: urls.primary), primaryBefore)
        XCTAssertEqual(try Data(contentsOf: urls.backup), backupBefore)
        XCTAssertFalse(FileManager.default.fileExists(atPath: urls.temporary.path))
    }

    private func makeStore() -> SaveStore {
        SaveStore(
            urls: SaveURLs(directory: directory),
            now: { [savedAt] in savedAt }
        )
    }

    private func stateWithAutoEquip(_ enabled: Bool) -> GameState {
        var state = GameState.newGame(balance: .standard)
        state.autoEquipEnabled = enabled
        return state
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected an error", file: file, line: line)
    } catch {
    }
}
