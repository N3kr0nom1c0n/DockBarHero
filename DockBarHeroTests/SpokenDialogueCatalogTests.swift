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
}

extension DialogueSpeaker {
    static let fixture = DialogueSpeaker(id: "book", displayName: "Book", rate: 0.45, pitch: 0.9, preferredVoiceTraits: ["theatrical"])
}

extension DialogueCue {
    static let fixture = DialogueCue(id: "book.test", speakerID: "book", unfiltered: "Test.", clean: "Test.", delivery: "flat", autoReadEligible: true)
}
