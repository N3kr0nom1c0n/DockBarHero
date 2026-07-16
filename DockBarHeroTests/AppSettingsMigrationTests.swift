import Foundation
import XCTest
@testable import DockBarHero

final class AppSettingsMigrationTests: XCTestCase {
    func testV1MigratesToV3LoreAndRailAppearanceDefaults() throws {
        let data = Data(
            #"{"animationMode":"paused","inputMode":"interactive","manualVisibility":"hidden","schemaVersion":1}"#.utf8
        )

        let settings = try SettingsCodec().decode(data)

        XCTAssertEqual(settings.schemaVersion, 3)
        XCTAssertEqual(settings.manualVisibility, .hidden)
        XCTAssertEqual(settings.animationMode, .paused)
        XCTAssertEqual(settings.inputMode, .interactive)
        XCTAssertEqual(settings.actorScalePercent, 100)
        XCTAssertEqual(settings.railTextScalePercent, 100)
        XCTAssertEqual(settings.loreLanguageMode, .unfiltered)
        XCTAssertEqual(settings.loreIllustrationMode, .safe)
        XCTAssertFalse(settings.spokenDialogueEnabled)
        XCTAssertEqual(settings.bookVolumeDetent, 5)
        XCTAssertTrue(settings.autoReadNewLorePages)
        XCTAssertFalse(settings.hasSeenCurrentRunPrologue)
        XCTAssertNil(settings.lastAutoReadLorePageID)
    }

    func testV2MigratesToV3RailAppearanceDefaults() throws {
        let data = Data(
            #"{"animationMode":"paused","autoReadNewLorePages":true,"bookVolumeDetent":5,"hasSeenCurrentRunPrologue":false,"inputMode":"interactive","loreIllustrationMode":"safe","loreLanguageMode":"unfiltered","manualVisibility":"hidden","schemaVersion":2,"spokenDialogueEnabled":false}"#.utf8
        )

        let settings = try SettingsCodec().decode(data)

        XCTAssertEqual(settings.schemaVersion, 3)
        XCTAssertEqual(settings.manualVisibility, .hidden)
        XCTAssertEqual(settings.animationMode, .paused)
        XCTAssertEqual(settings.inputMode, .interactive)
        XCTAssertEqual(settings.actorScalePercent, 100)
        XCTAssertEqual(settings.railTextScalePercent, 100)
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

    func testCodecRejectsOutOfRangeRailAppearanceValues() throws {
        let actorData = Data(
            #"{"actorScalePercent":141,"animationMode":"running","autoReadNewLorePages":true,"bookVolumeDetent":5,"hasSeenCurrentRunPrologue":false,"inputMode":"passive","loreIllustrationMode":"safe","loreLanguageMode":"unfiltered","manualVisibility":"shown","railTextScalePercent":100,"schemaVersion":3,"spokenDialogueEnabled":false}"#.utf8
        )
        let textData = Data(
            #"{"actorScalePercent":100,"animationMode":"running","autoReadNewLorePages":true,"bookVolumeDetent":5,"hasSeenCurrentRunPrologue":false,"inputMode":"passive","loreIllustrationMode":"safe","loreLanguageMode":"unfiltered","manualVisibility":"shown","railTextScalePercent":84,"schemaVersion":3,"spokenDialogueEnabled":false}"#.utf8
        )

        XCTAssertThrowsError(try SettingsCodec().decode(actorData)) { error in
            XCTAssertEqual(error as? SettingsDecodingError, .invalidActorScalePercent(141))
        }
        XCTAssertThrowsError(try SettingsCodec().decode(textData)) { error in
            XCTAssertEqual(error as? SettingsDecodingError, .invalidRailTextScalePercent(84))
        }
    }
}
