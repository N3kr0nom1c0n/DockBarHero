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
            "Speech only plays while the Book is open. Newly unlocked pages can auto-read when that option is on. Closing the Book stops speech."
        )
    }

    func testSettingsExplanationIsShortEnoughForSettingsSection() {
        XCTAssertLessThanOrEqual(LoreBookSpeechStatus.settingsExplanation.count, 160)
        XCTAssertTrue(LoreBookSpeechStatus.settingsExplanation.contains("Book is open"))
        XCTAssertTrue(LoreBookSpeechStatus.settingsExplanation.contains("Newly unlocked pages"))
        XCTAssertTrue(LoreBookSpeechStatus.settingsExplanation.contains("Closing the Book stops speech"))
    }
}
