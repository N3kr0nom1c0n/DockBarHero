import XCTest
@testable import DockBarHero

@MainActor
final class LoreReaderControllerTests: XCTestCase {
    func testSpeechNeverStartsWhileBookClosed() throws {
        let speech = LoreSpeechFake()
        let controller = try makeController(speech: speech)
        controller.update(settings: .spokenFixture, pages: [.fixture])
        controller.replay()
        XCTAssertTrue(speech.spoken.isEmpty)
    }

    func testClosingBookStopsAndClearsSpeech() throws {
        let speech = LoreSpeechFake()
        let controller = try makeController(speech: speech)
        controller.update(settings: .spokenFixture, pages: [.fixture])
        controller.applicationBecameActive()
        controller.open()
        controller.replay()
        controller.close()
        XCTAssertEqual(speech.stopCount, 1)
        XCTAssertEqual(speech.stopPreviewCount, 1)
        XCTAssertFalse(controller.isOpen)
    }

    func testVolumePreviewUsesReversedGainAndReplacesPreview() throws {
        let speech = LoreSpeechFake()
        let controller = try makeController(speech: speech)
        controller.update(settings: .spokenFixture, pages: [.fixture])
        controller.applicationBecameActive()
        controller.open()
        controller.previewVolume(detent: 0)
        controller.previewVolume(detent: 10)
        XCTAssertEqual(speech.previews.map(\.gain), [1.0, 0.1])
        XCTAssertEqual(speech.stopPreviewCount, 2)
    }

    func testInactiveApplicationIsSilentAndClearsQueues() throws {
        let speech = LoreSpeechFake()
        let controller = try makeController(speech: speech)
        controller.update(settings: .spokenFixture, pages: [.fixture])
        controller.applicationBecameActive()
        controller.open()
        let countBeforeInactiveReplay = speech.spoken.count
        controller.applicationBecameInactive()
        controller.replay()
        XCTAssertEqual(speech.spoken.count, countBeforeInactiveReplay)
        XCTAssertEqual(speech.stopCount, 1)
        XCTAssertEqual(speech.stopPreviewCount, 1)
    }

    func testDisabledSpeechStillShowsBookReaction() throws {
        let speech = LoreSpeechFake()
        let controller = try makeController(speech: speech)
        controller.update(settings: .defaults, pages: [.fixture])
        controller.open()
        controller.previewVolume(detent: 4)
        XCTAssertEqual(controller.reactionText, "Heh.")
        XCTAssertTrue(speech.previews.isEmpty)
    }

    func testAutoReadOnlyHappensOncePerSequentialPage() throws {
        let speech = LoreSpeechFake()
        let controller = try makeController(speech: speech)
        var recorded: [LorePageID] = []
        controller.onAutoReadPage = { recorded.append($0) }
        controller.update(settings: .spokenFixture, pages: [.fixture])

        controller.applicationBecameActive()
        controller.open()
        controller.close()
        controller.open()

        XCTAssertEqual(speech.spoken.count, 1)
        XCTAssertEqual(recorded.map(\.rawValue), ["test"])
    }

    func testOpeningBeforeApplicationIsActiveDefersAutoReadUntilActivation() throws {
        let speech = LoreSpeechFake()
        let controller = try makeController(speech: speech)
        var recorded: [LorePageID] = []
        controller.onAutoReadPage = { recorded.append($0) }
        controller.update(settings: .spokenFixture, pages: [.fixture])

        controller.open()

        XCTAssertTrue(speech.spoken.isEmpty)
        XCTAssertTrue(recorded.isEmpty)

        controller.applicationBecameActive()

        XCTAssertEqual(speech.spoken.map(\.id), ["book.test"])
        XCTAssertEqual(recorded.map(\.rawValue), ["test"])
    }
}

@MainActor
final class LoreSpeechFake: LoreSpeechControlling {
    var spoken: [ResolvedDialogueCue] = []
    var previews: [(text: String, gain: Float)] = []
    var stopCount = 0
    var stopPreviewCount = 0
    func speak(_ cue: ResolvedDialogueCue, gain: Float) { spoken.append(cue) }
    func stop() { stopCount += 1 }
    func stopPreview() { stopPreviewCount += 1 }
    func previewGiggle(_ text: String, gain: Float) { previews.append((text, gain)) }
}

@MainActor
private func makeController(speech: LoreSpeechControlling) throws -> LoreReaderController {
    let catalog = try SpokenDialogueCatalog.validated(.init(schemaVersion: 1, speakers: [.fixture], cues: [.fixture]))
    return LoreReaderController(dialogue: catalog, speech: speech)
}

extension AppSettings {
    static var spokenFixture: AppSettings {
        var value = defaults
        value.spokenDialogueEnabled = true
        return value
    }
}

extension ResolvedLorePage {
    static let fixture = ResolvedLorePage(
        id: LorePageID(rawValue: "test"), title: "Test", body: "Test",
        spriteSheetName: "test", accessibilityDescription: "Test",
        composition: ResolvedLoreComposition(
            layoutID: .cascadeFive,
            contextSheetName: "test-context-safe",
            panels: [
                .init(id: "p1", slotID: "slot1", role: .still, sourceCell: 0, readingOrder: 0, focalPoint: .init(x: 0.5, y: 0.5)),
                .init(id: "p2", slotID: "slot2", role: .motion, sourceCell: nil, readingOrder: 1, focalPoint: .init(x: 0.5, y: 0.5)),
                .init(id: "p3", slotID: "slot3", role: .still, sourceCell: 1, readingOrder: 2, focalPoint: .init(x: 0.5, y: 0.5)),
                .init(id: "p4", slotID: "slot4", role: .still, sourceCell: 2, readingOrder: 3, focalPoint: .init(x: 0.5, y: 0.5)),
                .init(id: "p5", slotID: "slot5", role: .gag, sourceCell: 3, readingOrder: 4, focalPoint: .init(x: 0.5, y: 0.5))
            ],
            textOverlays: []
        ),
        dialogueCueIDs: ["book.test"], frameCount: 4, frameDurationMilliseconds: 600
    )
}
