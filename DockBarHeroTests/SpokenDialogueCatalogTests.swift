import XCTest
@testable import DockBarHero

final class SpokenDialogueCatalogTests: XCTestCase {
    func testBundledDialogueValidatesAllLoreReferences() throws {
        let lore = try LoreCatalog.bundled()
        let dialogue = try SpokenDialogueCatalog.bundled(loreCatalog: lore)
        XCTAssertEqual(dialogue.speakers.count, 6)
        for page in lore.pages {
            for cueID in page.dialogueCueIDs {
                XCTAssertNotNil(dialogue.resolve(cueID: cueID, languageMode: .unfiltered))
            }
        }
    }

    func testRejectsDuplicateSpeakerAndCueIDs() {
        let speaker = DialogueSpeaker.fixture
        let cue = DialogueCue.fixture
        XCTAssertThrowsError(try SpokenDialogueCatalog.validated(.init(schemaVersion: 1, speakers: [speaker, speaker], cues: [cue])))
        XCTAssertThrowsError(try SpokenDialogueCatalog.validated(.init(schemaVersion: 1, speakers: [speaker], cues: [cue, cue])))
    }

    func testRejectsUnknownSpeakerAndMissingLanguageVariant() {
        let unknown = DialogueCue(id: "unknown", speakerID: "missing", unfiltered: "Hi", clean: "Hi", delivery: "flat", autoReadEligible: true)
        XCTAssertThrowsError(try SpokenDialogueCatalog.validated(.init(schemaVersion: 1, speakers: [.fixture], cues: [unknown])))

        let emptyClean = DialogueCue(id: "empty", speakerID: "book", unfiltered: "Nope", clean: "", delivery: "flat", autoReadEligible: true)
        XCTAssertThrowsError(try SpokenDialogueCatalog.validated(.init(schemaVersion: 1, speakers: [.fixture], cues: [emptyClean])))
    }

    func testCleanModeNeverReturnsPrologueProfanity() throws {
        let dialogue = try SpokenDialogueCatalog.bundled(loreCatalog: LoreCatalog.bundled())
        let cue = try XCTUnwrap(dialogue.resolve(cueID: "prologue.book.wrong-way", languageMode: .clean))
        XCTAssertFalse(cue.text.lowercased().contains("fuck"))
        XCTAssertFalse(cue.text.lowercased().contains("jackass"))
        XCTAssertTrue(cue.text.contains("hamburger enthusiast"))
    }

    func testEveryOverlayDialogueCueExistsAndMatchesSpokenSidecar() throws {
        let lore = try LoreCatalog.bundled()
        let spoken = try SpokenDialogueCatalog.bundled(loreCatalog: lore)
        let cueIDs = Set(spoken.cues.map(\.id))

        for overlay in lore.pages.flatMap({ $0.composition.textOverlays }) {
            guard let cueID = overlay.dialogueCueID else { continue }
            XCTAssertTrue(cueIDs.contains(cueID), cueID)
            XCTAssertEqual(
                spoken.resolve(cueID: cueID, languageMode: .unfiltered)?.text,
                overlay.copy.unfiltered,
                cueID
            )
            XCTAssertEqual(
                spoken.resolve(cueID: cueID, languageMode: .clean)?.text,
                overlay.copy.clean,
                cueID
            )
        }
    }

    func testOnlyApprovedOverlayLinesAreVoiced() throws {
        let lore = try LoreCatalog.bundled()
        let overlayCueIDs = lore.pages.flatMap { page in
            page.composition.textOverlays.compactMap(\.dialogueCueID)
        }

        XCTAssertEqual(overlayCueIDs, [
            "prologue.book.wrong-way", "prologue.book.arrow-denial",
            "book.level1.summary", "kevin.not-kevin",
            "book.level5.summary", "kevin.supervisor",
            "book.level10.summary",
            "book.level15.summary", "brick.policy-warning",
            "book.level20.summary", "mercy.therapy-referral"
        ])

        let voicedStyles = lore.pages.flatMap(\.composition.textOverlays)
            .filter { $0.dialogueCueID != nil }
            .map(\.style)
        XCTAssertFalse(voicedStyles.contains(.soundEffect))
    }
}

extension DialogueSpeaker {
    static let fixture = DialogueSpeaker(id: "book", displayName: "Book", rate: 0.45, pitch: 0.9, preferredVoiceTraits: ["theatrical"])
}

extension DialogueCue {
    static let fixture = DialogueCue(id: "book.test", speakerID: "book", unfiltered: "Test.", clean: "Test.", delivery: "flat", autoReadEligible: true)
}
