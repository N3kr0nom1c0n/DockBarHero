import Foundation
import XCTest
@testable import DockBarHero

@MainActor
final class SettingsSessionTests: XCTestCase {
    func testStartLoadsOnceAndPublishesSettings() async {
        let expected = AppSettings(
            schemaVersion: AppSettings.currentVersion,
            manualVisibility: .hidden,
            animationMode: .paused,
            inputMode: .passive
        )
        let store = SettingsStoreFake(loaded: expected)
        let session = SettingsSession(store: store)
        var received: [AppSettings] = []
        session.onSettings = { received.append($0) }

        session.start()
        session.start()
        await waitUntil { await store.currentLoadCount() == 1 && received == [expected] }
    }

    func testUpdateSubmitsLatestSettings() async {
        let store = SettingsStoreFake(loaded: .defaults)
        let session = SettingsSession(store: store)
        session.start()
        await waitUntil { await store.currentLoadCount() == 1 }
        var updated = AppSettings.defaults
        updated.inputMode = .interactive

        session.update(updated)

        await waitUntil { await store.hasSaved(updated) }
    }

    func testStopAndSaveAwaitsFinalLatestSettingsSave() async {
        let store = SettingsStoreFake(loaded: .defaults)
        let session = SettingsSession(store: store)
        session.start()
        await waitUntil { await store.currentLoadCount() == 1 }
        var latest = AppSettings.defaults
        latest.animationMode = .paused
        session.update(latest)

        await session.stopAndSave()

        let lastSaved = await store.lastSaved()
        XCTAssertEqual(lastSaved, latest)
    }

    private func waitUntil(
        _ predicate: @escaping @MainActor () async -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<1_000 {
            if await predicate() { return }
            await Task.yield()
        }
        XCTFail("condition not met", file: file, line: line)
    }
}

private actor SettingsStoreFake: SettingsStoring {
    let loaded: AppSettings
    private(set) var loadCount = 0
    private(set) var saved: [AppSettings] = []

    init(loaded: AppSettings) {
        self.loaded = loaded
    }

    func load() async -> AppSettings {
        loadCount += 1
        return loaded
    }

    func save(_ settings: AppSettings) async throws {
        saved.append(settings)
    }

    func currentLoadCount() -> Int { loadCount }
    func hasSaved(_ settings: AppSettings) -> Bool { saved.contains(settings) }
    func lastSaved() -> AppSettings? { saved.last }
}
