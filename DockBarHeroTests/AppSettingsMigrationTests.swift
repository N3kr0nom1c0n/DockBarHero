import Foundation
import XCTest
@testable import DockBarHero

final class AppSettingsMigrationTests: XCTestCase {
    func testV1MigratesToV2LoreDefaults() throws {
        let data = Data(
            #"{"animationMode":"paused","inputMode":"interactive","manualVisibility":"hidden","schemaVersion":1}"#.utf8
        )

        let settings = try SettingsCodec().decode(data)

        XCTAssertEqual(settings.schemaVersion, 2)
        XCTAssertEqual(settings.manualVisibility, .hidden)
        XCTAssertEqual(settings.animationMode, .paused)
        XCTAssertEqual(settings.inputMode, .interactive)
        XCTAssertEqual(settings.loreLanguageMode, .unfiltered)
        XCTAssertEqual(settings.loreIllustrationMode, .safe)
        XCTAssertFalse(settings.spokenDialogueEnabled)
        XCTAssertEqual(settings.bookVolumeDetent, 5)
        XCTAssertTrue(settings.autoReadNewLorePages)
        XCTAssertFalse(settings.hasSeenCurrentRunPrologue)
        XCTAssertNil(settings.lastAutoReadLorePageID)
    }

    func testReversedVolumeEndpoints() {
        var settings = AppSettings.defaults
        settings.bookVolumeDetent = 0
        XCTAssertEqual(settings.bookOutputGain, 1.0, accuracy: 0.000_1)

        settings.bookVolumeDetent = 10
        XCTAssertEqual(settings.bookOutputGain, 0.1, accuracy: 0.000_1)
    }

    func testCodecRejectsOutOfRangeDetent() throws {
        let data = Data(
            #"{"animationMode":"running","autoReadNewLorePages":true,"bookVolumeDetent":11,"hasSeenCurrentRunPrologue":false,"inputMode":"passive","loreIllustrationMode":"safe","loreLanguageMode":"unfiltered","manualVisibility":"shown","schemaVersion":2,"spokenDialogueEnabled":false}"#.utf8
        )

        XCTAssertThrowsError(try SettingsCodec().decode(data))
    }
}
