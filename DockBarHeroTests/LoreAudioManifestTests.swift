import XCTest
@testable import DockBarHero

final class LoreAudioManifestTests: XCTestCase {
    func testManifestResolvesLanguageSpecificAssets() throws {
        let manifest = LoreAudioManifest(schemaVersion: 1, entries: [
            .init(cueID: "book.test", unfiltered: "book.test.unfiltered.mp3", clean: "book.test.clean.mp3")
        ])

        XCTAssertEqual(manifest.assetName(cueID: "book.test", languageMode: .unfiltered), "book.test.unfiltered.mp3")
        XCTAssertEqual(manifest.assetName(cueID: "book.test", languageMode: .clean), "book.test.clean.mp3")
        XCTAssertNil(manifest.assetName(cueID: "missing", languageMode: .clean))
    }

    func testBundledManifestRejectsDuplicateCueIDs() throws {
        let manifest = LoreAudioManifest(schemaVersion: 1, entries: [
            .init(cueID: "book.test", unfiltered: "a.mp3", clean: "a.mp3"),
            .init(cueID: "book.test", unfiltered: "b.mp3", clean: "b.mp3")
        ])

        XCTAssertThrowsError(try LoreAudioManifest.validated(manifest)) { error in
            XCTAssertEqual(error as? LoreAudioManifestError, .duplicateCueID("book.test"))
        }
    }

    @MainActor
    func testRecordedSpeechServiceValidatesEveryBundledManifestAsset() throws {
        let appBundle = Bundle(for: AppDelegate.self)
        let manifest = try LoreAudioManifest.bundled(bundle: appBundle)
        let dialogue = try SpokenDialogueCatalog.bundled(bundle: appBundle, loreCatalog: LoreCatalog.bundled(bundle: appBundle))

        for assetName in manifest.entries.flatMap({ [$0.unfiltered, $0.clean] }) {
            let name = (assetName as NSString).deletingPathExtension
            let ext = (assetName as NSString).pathExtension
            XCTAssertNotNil(appBundle.url(forResource: name, withExtension: ext), "Missing bundled audio asset: \(assetName)")
        }
        XCTAssertNoThrow(try RecordedLoreSpeechService(bundle: appBundle, dialogue: dialogue))
    }

    func testManifestCoverageRejectsMissingDialogueCue() throws {
        let dialogue = SpokenDialogueCatalog(schemaVersion: 1, speakers: [.fixture], cues: [.fixture])
        let manifest = LoreAudioManifest(schemaVersion: 1, entries: [])

        XCTAssertThrowsError(try manifest.validateCoverage(for: dialogue)) { error in
            XCTAssertEqual(error as? LoreAudioManifestError, .missingCueID("book.test"))
        }
    }

    func testManifestCoverageRejectsUnexpectedCue() throws {
        let dialogue = SpokenDialogueCatalog(schemaVersion: 1, speakers: [.fixture], cues: [])
        let manifest = LoreAudioManifest(schemaVersion: 1, entries: [
            .init(cueID: "book.test", unfiltered: "book.test.unfiltered.mp3", clean: "book.test.clean.mp3")
        ])

        XCTAssertThrowsError(try manifest.validateCoverage(for: dialogue)) { error in
            XCTAssertEqual(error as? LoreAudioManifestError, .unexpectedCueID("book.test"))
        }
    }

    func testManifestCoverageRejectsSharedCleanAssetWhenTextDiffers() throws {
        let cue = DialogueCue(id: "book.test", speakerID: "book", unfiltered: "Nope.", clean: "No thank you.", delivery: "flat", autoReadEligible: true)
        let dialogue = SpokenDialogueCatalog(schemaVersion: 1, speakers: [.fixture], cues: [cue])
        let manifest = LoreAudioManifest(schemaVersion: 1, entries: [
            .init(cueID: "book.test", unfiltered: "book.test.unfiltered.mp3", clean: "book.test.unfiltered.mp3")
        ])

        XCTAssertThrowsError(try manifest.validateCoverage(for: dialogue)) { error in
            XCTAssertEqual(error as? LoreAudioManifestError, .cleanVariantRequiresDistinctAsset("book.test"))
        }
    }

    @MainActor
    func testRecordedSpeechUsesCleanAssetWhenCueIsClean() throws {
        let manifest = LoreAudioManifest(schemaVersion: 1, entries: [
            .init(cueID: "book.test", unfiltered: "book.test.unfiltered.mp3", clean: "book.test.clean.mp3")
        ])
        let player = LoreAudioPlayerFake()
        let service = RecordedLoreSpeechService(manifest: manifest, player: player, previewPlayer: LoreAudioPlayerFake())
        let cue = ResolvedDialogueCue(id: "book.test", speaker: .fixture, text: "Clean", delivery: "flat", languageMode: .clean)

        service.speak(cue, gain: 0.4)

        XCTAssertEqual(player.played.map(\.resourceName), ["book.test.clean.mp3"])
        XCTAssertEqual(player.played.map(\.gain), [0.4])
    }
}

@MainActor
private final class LoreAudioPlayerFake: LoreAudioPlaying {
    var played: [(resourceName: String, gain: Float)] = []
    var stopCount = 0
    func play(resourceName: String, gain: Float) { played.append((resourceName, gain)) }
    func stop() { stopCount += 1 }
}
