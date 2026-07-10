import XCTest
@testable import DockBarHero

final class OverlayStateTests: XCTestCase {
    func testDefaultsAreShownAnimatingAndPassive() {
        let state = OverlayState()

        XCTAssertEqual(state.manualVisibility, .shown)
        XCTAssertEqual(state.environmentVisibility, .normalSpace)
        XCTAssertEqual(state.animationMode, .running)
        XCTAssertEqual(state.inputMode, .passive)
        XCTAssertTrue(state.isEffectivelyVisible)
        XCTAssertTrue(state.shouldAnimate)
        XCTAssertFalse(state.acceptsInput)
    }

    func testManualHideWinsAcrossEnvironmentChanges() {
        var state = OverlayState()

        state.apply(.setManualVisibility(.hidden))
        state.apply(.setEnvironmentVisibility(.fullscreen))
        state.apply(.setEnvironmentVisibility(.normalSpace))

        XCTAssertFalse(state.isEffectivelyVisible)
        XCTAssertEqual(state.manualVisibility, .hidden)
    }

    func testFullscreenSuppressesVisibilityAndAnimation() {
        var state = OverlayState(inputMode: .interactive)

        state.apply(.setEnvironmentVisibility(.fullscreen))

        XCTAssertFalse(state.isEffectivelyVisible)
        XCTAssertFalse(state.shouldAnimate)
        XCTAssertFalse(state.acceptsInput)
    }

    func testPauseAndInteractiveActionsAreIndependent() {
        var state = OverlayState()

        state.apply(.setAnimationMode(.paused))
        state.apply(.setInputMode(.interactive))

        XCTAssertFalse(state.shouldAnimate)
        XCTAssertTrue(state.acceptsInput)
    }
}
