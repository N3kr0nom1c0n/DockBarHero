import XCTest
@testable import DockBarHero

final class LoreBookSpeechStatusTests: XCTestCase {
    func testFooterTextWhenSpeechIsOff() {
        var settings = AppSettings.defaults
        settings.spokenDialogueEnabled = false
        settings.autoReadNewLorePages = true

        XCTAssertEqual(
            LoreBookSpeechStatus.footerText(settings: settings),
            "Spoken dialogue is off."
        )
    }

    func testFooterTextWhenSpeechIsOnAndAutoReadIsOff() {
        var settings = AppSettings.defaults
        settings.spokenDialogueEnabled = true
        settings.autoReadNewLorePages = false

        XCTAssertEqual(
            LoreBookSpeechStatus.footerText(settings: settings),
            "Replay reads this page. New pages will not auto-read."
        )
    }

    func testFooterTextWhenSpeechAndAutoReadAreOn() {
        var settings = AppSettings.defaults
        settings.spokenDialogueEnabled = true
        settings.autoReadNewLorePages = true

        XCTAssertEqual(
            LoreBookSpeechStatus.footerText(settings: settings),
            "Replay reads this page. Newly unlocked pages can auto-read while the Book is open."
        )
    }

    func testSettingsExplanationNamesOpenBookAndNewPages() {
        XCTAssertEqual(
            LoreBookSpeechStatus.settingsExplanation,
            "Speech only plays while the Book is visibly open and the app is active. Newly unlocked pages can auto-read when that option is on. Closing the Book stops speech."
        )
    }

    func testSettingsExplanationIsShortEnoughForSettingsSection() {
        XCTAssertLessThanOrEqual(LoreBookSpeechStatus.settingsExplanation.count, 170)
        XCTAssertTrue(LoreBookSpeechStatus.settingsExplanation.contains("Book is visibly open"))
        XCTAssertTrue(LoreBookSpeechStatus.settingsExplanation.contains("app is active"))
        XCTAssertTrue(LoreBookSpeechStatus.settingsExplanation.contains("Newly unlocked pages"))
        XCTAssertTrue(LoreBookSpeechStatus.settingsExplanation.contains("Closing the Book stops speech"))
    }

    func testFooterCopyStaysCompact() {
        for spoken in [false, true] {
            for autoRead in [false, true] {
                var settings = AppSettings.defaults
                settings.spokenDialogueEnabled = spoken
                settings.autoReadNewLorePages = autoRead

                let text = LoreBookSpeechStatus.footerText(settings: settings)

                XCTAssertLessThanOrEqual(text.count, 88)
                XCTAssertFalse(text.contains("\n"))
            }
        }
    }
}
