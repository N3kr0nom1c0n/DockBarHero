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
