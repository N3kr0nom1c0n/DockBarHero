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

        XCTAssertEqual(urls.primary.lastPathComponent, "save-v2.json")
        XCTAssertEqual(urls.backup.lastPathComponent, "save-v2.backup.json")
        XCTAssertEqual(urls.temporary.lastPathComponent, "save-v2.pending.json")
    }

    func testApplicationSupportURLsUseDockBarHeroDirectory() {
        let urls = SaveURLs.applicationSupport

        XCTAssertEqual(urls.directory.lastPathComponent, "com.n3kr0nom1c0n.DockBarHero")
        XCTAssertEqual(urls.directory.deletingLastPathComponent().lastPathComponent, "Application Support")
    }

    func testAbsentV2RequiresClassSelection() async {
        let result = await makeStore().load()

        XCTAssertEqual(result.runState, .classSelection)
        XCTAssertEqual(result.source, .newGame)
    }

    func testFailedReplaceKeepsOldRunLoadable() async throws {
        let urls = SaveURLs(directory: directory)
        let oldState = GameState.newGame(balance: .standard)
        try SaveCodec().encode(state: oldState, savedAt: savedAt).write(to: urls.primary)
        let store = SaveStore(
            urls: urls,
            fileSystem: MutationFailingFileSystem(failure: .installPrimary(urls.primary)),
            codec: SaveCodec(),
            now: { [savedAt] in savedAt }
        )

        await XCTAssertThrowsErrorAsync(try await store.replaceRun(with: .classSelection))

        let recovered = await makeStore().load()
        XCTAssertEqual(recovered.runState, .active(oldState))
    }

    func testFailedReplacePreservesBackupOnlyRecoveredRun() async throws {
        let urls = SaveURLs(directory: directory)
        let oldState = GameState.newGame(balance: .standard)
        try SaveCodec().encode(state: oldState, savedAt: savedAt).write(to: urls.backup)
        let store = SaveStore(
            urls: urls,
            fileSystem: MutationFailingFileSystem(failure: .installPrimary(urls.primary)),
            codec: SaveCodec(),
            now: { [savedAt] in savedAt }
        )

        await XCTAssertThrowsErrorAsync(try await store.replaceRun(with: .classSelection))

        let recovered = await makeStore().load()
        XCTAssertEqual(recovered.runState, .active(oldState))
        XCTAssertEqual(recovered.source, .backup)
    }


    func testSuccessfulResetCannotRecoverOldBackup() async throws {
        let store = makeStore()
        let oldState = GameState.newGame(balance: .standard)
        var newerOldState = oldState
        newerOldState.autoEquipEnabled = false
        try await store.save(oldState)
        try await store.save(newerOldState)

        try await store.replaceRun(with: .classSelection)
        let urls = SaveURLs(directory: directory)
        try Data("corrupt-reset".utf8).write(to: urls.primary)

        let recovered = await store.load()
        XCTAssertEqual(recovered.runState, .classSelection)
        XCTAssertFalse(FileManager.default.fileExists(atPath: urls.backup.path))
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
        XCTAssertNil(result.issue)
        let quarantined = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.contains("save-v2.json.invalid-") }
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

        XCTAssertEqual(result.state, backupState)
        XCTAssertEqual(result.source, .backup)
        XCTAssertEqual(result.issue, .unsupportedVersion(99))
        let quarantined = try XCTUnwrap(try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).first { $0.lastPathComponent.contains(".invalid-") })
        XCTAssertEqual(try Data(contentsOf: quarantined), futureData)
    }

    func testUnsupportedFuturePrimaryWithoutUsableBackupStartsNewGameWithIssue() async throws {
        let store = makeStore()
        let urls = SaveURLs(directory: directory)
        let futureData = Data(#"{"schemaVersion":99,"savedAt":"2026-07-10T00:00:00Z","state":{}}"#.utf8)
        try futureData.write(to: urls.primary)
        let newGame = stateWithAutoEquip(false)

        let result = await store.load(newGame: newGame)

        XCTAssertEqual(result.state, newGame)
        XCTAssertEqual(result.source, .newGame)
        XCTAssertEqual(result.issue, .unsupportedVersion(99))
        let quarantined = try XCTUnwrap(try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).first { $0.lastPathComponent.contains("save-v2.json.invalid-") })
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

    func testCorruptPrimaryDoesNotDisplaceValidBackupWhenPrimaryInstallFails() async throws {
        let urls = SaveURLs(directory: directory)
        let backupState = GameState.newGame(balance: .standard)
        let backupData = try SaveCodec().encode(state: backupState, savedAt: savedAt)
        let corruptPrimaryData = Data("corrupt-primary".utf8)
        try backupData.write(to: urls.backup)
        try corruptPrimaryData.write(to: urls.primary)

        let fileSystem = MutationFailingFileSystem(failure: .installPrimary(urls.primary))
        let store = SaveStore(
            urls: urls,
            fileSystem: fileSystem,
            codec: SaveCodec(),
            now: { [savedAt] in savedAt }
        )

        await XCTAssertThrowsErrorAsync(try await store.save(stateWithAutoEquip(false)))

        XCTAssertEqual(try SaveCodec().decode(Data(contentsOf: urls.backup)).state, backupState)
        XCTAssertFalse(FileManager.default.fileExists(atPath: urls.temporary.path))
        let quarantinedPrimary = try XCTUnwrap(FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).first { $0.lastPathComponent.contains("save-v2.json.invalid-") })
        XCTAssertEqual(try Data(contentsOf: quarantinedPrimary), corruptPrimaryData)

        let recovery = await makeStore().load(newGame: stateWithAutoEquip(false))
        XCTAssertEqual(recovery, SaveLoadResult(state: backupState, source: .backup))
    }

    func testPrimaryQuarantineFailurePreservesCorruptPrimaryAndValidBackup() async throws {
        let urls = SaveURLs(directory: directory)
        let backupState = GameState.newGame(balance: .standard)
        let backupData = try SaveCodec().encode(state: backupState, savedAt: savedAt)
        let corruptPrimaryData = Data("corrupt-primary".utf8)
        try backupData.write(to: urls.backup)
        try corruptPrimaryData.write(to: urls.primary)
        let store = SaveStore(
            urls: urls,
            fileSystem: MutationFailingFileSystem(failure: .quarantine(urls.primary)),
            codec: SaveCodec(),
            now: { [savedAt] in savedAt }
        )

        await XCTAssertThrowsErrorAsync(try await store.save(stateWithAutoEquip(false)))

        XCTAssertEqual(try Data(contentsOf: urls.primary), corruptPrimaryData)
        XCTAssertEqual(try SaveCodec().decode(Data(contentsOf: urls.backup)).state, backupState)
        XCTAssertFalse(FileManager.default.fileExists(atPath: urls.temporary.path))
    }

    func testBackupStagingFailurePreservesValidPrimaryAndBackup() async throws {
        let urls = SaveURLs(directory: directory)
        let (primaryData, backupData) = try seedDistinctValidPrimaryAndBackup(at: urls)
        let store = SaveStore(
            urls: urls,
            fileSystem: MutationFailingFileSystem(failure: .stageBackup),
            codec: SaveCodec(),
            now: { [savedAt] in savedAt }
        )

        await XCTAssertThrowsErrorAsync(try await store.save(stateWithHeroHealth(98)))

        XCTAssertEqual(try Data(contentsOf: urls.primary), primaryData)
        XCTAssertEqual(try Data(contentsOf: urls.backup), backupData)
        XCTAssertFalse(FileManager.default.fileExists(atPath: urls.temporary.path))
    }

    func testBackupReplacementFailurePreservesValidPrimaryAndBackup() async throws {
        let urls = SaveURLs(directory: directory)
        let (primaryData, backupData) = try seedDistinctValidPrimaryAndBackup(at: urls)
        let store = SaveStore(
            urls: urls,
            fileSystem: MutationFailingFileSystem(failure: .replaceBackup(urls.backup)),
            codec: SaveCodec(),
            now: { [savedAt] in savedAt }
        )

        await XCTAssertThrowsErrorAsync(try await store.save(stateWithHeroHealth(98)))

        XCTAssertEqual(try Data(contentsOf: urls.primary), primaryData)
        XCTAssertEqual(try Data(contentsOf: urls.backup), backupData)
        XCTAssertFalse(FileManager.default.fileExists(atPath: urls.temporary.path))
    }

    func testPrimaryReplacementFailureLeavesPriorPrimaryInBothDurableSlots() async throws {
        let urls = SaveURLs(directory: directory)
        let (primaryData, _) = try seedDistinctValidPrimaryAndBackup(at: urls)
        let store = SaveStore(
            urls: urls,
            fileSystem: MutationFailingFileSystem(failure: .installPrimary(urls.primary)),
            codec: SaveCodec(),
            now: { [savedAt] in savedAt }
        )

        await XCTAssertThrowsErrorAsync(try await store.save(stateWithHeroHealth(98)))

        XCTAssertEqual(try Data(contentsOf: urls.primary), primaryData)
        XCTAssertEqual(try Data(contentsOf: urls.backup), primaryData)
        XCTAssertFalse(FileManager.default.fileExists(atPath: urls.temporary.path))
    }

    func testUnreadableBackupIsQuarantinedBeforeValidPrimaryReplacesIt() async throws {
        let urls = SaveURLs(directory: directory)
        let primaryState = GameState.newGame(balance: .standard)
        var newState = primaryState
        newState.autoEquipEnabled = false
        let unreadableBackup = Data("unreadable-backup".utf8)
        try SaveCodec().encode(state: primaryState, savedAt: savedAt).write(to: urls.primary)
        try unreadableBackup.write(to: urls.backup)

        try await makeStore().save(newState)

        XCTAssertEqual(try SaveCodec().decode(Data(contentsOf: urls.primary)).state, newState)
        XCTAssertEqual(try SaveCodec().decode(Data(contentsOf: urls.backup)).state, primaryState)
        let quarantinedBackup = try XCTUnwrap(FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).first { $0.lastPathComponent.contains("save-v2.backup.json.invalid-") })
        XCTAssertEqual(try Data(contentsOf: quarantinedBackup), unreadableBackup)
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

    private func stateWithHeroHealth(_ health: Int) -> GameState {
        var state = GameState.newGame(balance: .standard)
        state.hero.currentHealth = health
        return state
    }

    private func seedDistinctValidPrimaryAndBackup(at urls: SaveURLs) throws -> (primary: Data, backup: Data) {
        let primary = try SaveCodec().encode(state: stateWithHeroHealth(99), savedAt: savedAt)
        let backup = try SaveCodec().encode(state: GameState.newGame(balance: .standard), savedAt: savedAt)
        try primary.write(to: urls.primary)
        try backup.write(to: urls.backup)
        return (primary, backup)
    }
}

private enum InjectedFileSystemError: Error {
    case primaryInstall
}

private enum InjectedFailurePoint: Sendable {
    case quarantine(URL)
    case stageBackup
    case replaceBackup(URL)
    case installPrimary(URL)
}

private struct MutationFailingFileSystem: SaveFileSystem {
    private let failure: InjectedFailurePoint

    init(failure: InjectedFailurePoint) {
        self.failure = failure
    }

    func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func read(from url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    func write(_ data: Data, to url: URL, options: Data.WritingOptions) throws {
        if case .stageBackup = failure,
           url.lastPathComponent.hasPrefix(".save-v2.backup-") {
            throw InjectedFileSystemError.primaryInstall
        }
        try data.write(to: url, options: options)
    }

    func moveItem(at source: URL, to destination: URL) throws {
        if case .quarantine(let quarantinedURL) = failure,
           source.standardizedFileURL == quarantinedURL.standardizedFileURL,
           destination.lastPathComponent.contains(".invalid-") {
            throw InjectedFileSystemError.primaryInstall
        }
        if case .installPrimary(let primary) = failure,
           destination.standardizedFileURL == primary.standardizedFileURL {
            throw InjectedFileSystemError.primaryInstall
        }
        try FileManager.default.moveItem(at: source, to: destination)
    }

    func replaceItem(at destination: URL, with source: URL) throws {
        if case .replaceBackup(let backup) = failure,
           destination.standardizedFileURL == backup.standardizedFileURL {
            throw InjectedFileSystemError.primaryInstall
        }
        if case .installPrimary(let primary) = failure,
           destination.standardizedFileURL == primary.standardizedFileURL {
            throw InjectedFileSystemError.primaryInstall
        }
        _ = try FileManager.default.replaceItemAt(destination, withItemAt: source)
    }

    func removeItem(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
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
