enum LoreBookSpeechStatus {
    static let settingsExplanation =
        "Speech only plays while the Book is visibly open and the app is active. Newly unlocked pages can auto-read when that option is on. Closing the Book stops speech."

    static func footerText(settings: AppSettings) -> String {
        guard settings.spokenDialogueEnabled else {
            return "Spoken dialogue is off."
        }
        if settings.autoReadNewLorePages {
            return "Replay reads this page. Newly unlocked pages can auto-read while the Book is open."
        }
        return "Replay reads this page. New pages will not auto-read."
    }
}
