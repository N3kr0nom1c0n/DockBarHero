import XCTest
@testable import DockBarHero

final class AreaTitleMarqueeTests: XCTestCase {
    private let fullName = "The Forgotten Shallow Depths That Were Remembered"
    private let shortName = "Shallow Depths"

    func testInitialAuthoredAreaStartsFullTitleScroll() {
        var state = AreaTitleMarqueeState()

        state.present(
            areaID: .forgottenShallowDepths,
            fullName: fullName,
            shortName: shortName,
            animationsEnabled: true
        )

        XCTAssertEqual(state.areaID, .forgottenShallowDepths)
        XCTAssertEqual(state.phase, .scrolling(fullName: fullName, shortName: shortName))
    }

    func testCompletedScrollSettlesAndSameAreaPresentationIsStable() {
        var state = presentedState()
        state.completeScroll()

        state.present(
            areaID: .forgottenShallowDepths,
            fullName: "Changed Copy Must Not Restart",
            shortName: "Changed",
            animationsEnabled: true
        )

        XCTAssertEqual(state.phase, .settled(shortName: shortName))
    }

    func testDifferentAreaRestartsFullTitleScroll() {
        var state = presentedState()
        state.completeScroll()

        state.present(
            areaID: AreaID(rawValue: "area.two"),
            fullName: "Area Two Full Name",
            shortName: "Area Two",
            animationsEnabled: true
        )

        XCTAssertEqual(state.areaID, AreaID(rawValue: "area.two"))
        XCTAssertEqual(
            state.phase,
            .scrolling(fullName: "Area Two Full Name", shortName: "Area Two")
        )
    }

    func testHideClearsAreaAndHoverStateSoAreaReplaysWhenPresentedAgain() {
        var state = presentedState()
        state.completeScroll()
        XCTAssertFalse(state.advanceHover(
            by: 1,
            inside: true,
            interactive: true,
            animationsEnabled: true
        ))

        state.hide()

        XCTAssertNil(state.areaID)
        XCTAssertEqual(state.phase, .hidden)
        state.present(
            areaID: .forgottenShallowDepths,
            fullName: fullName,
            shortName: shortName,
            animationsEnabled: true
        )
        XCTAssertEqual(state.phase, .scrolling(fullName: fullName, shortName: shortName))
        XCTAssertFalse(state.advanceHover(
            by: 2,
            inside: true,
            interactive: true,
            animationsEnabled: true
        ))
    }

    func testDisabledAnimationsSettleImmediatelyAndRejectHiddenHoverTime() {
        var state = AreaTitleMarqueeState()
        state.present(
            areaID: .forgottenShallowDepths,
            fullName: fullName,
            shortName: shortName,
            animationsEnabled: false
        )

        XCTAssertEqual(state.phase, .settled(shortName: shortName))
        XCTAssertFalse(state.advanceHover(
            by: 3,
            inside: true,
            interactive: true,
            animationsEnabled: false
        ))
        XCTAssertEqual(state.phase, .settled(shortName: shortName))
        XCTAssertFalse(state.advanceHover(
            by: 0,
            inside: true,
            interactive: true,
            animationsEnabled: true
        ))
    }

    func testInterruptedInitialPassReplaysOnceWhenAnimationsBecomeEnabled() {
        var state = presentedState()

        state.present(
            areaID: .forgottenShallowDepths,
            fullName: fullName,
            shortName: shortName,
            animationsEnabled: false
        )
        XCTAssertEqual(state.phase, .settled(shortName: shortName))

        state.present(
            areaID: .forgottenShallowDepths,
            fullName: fullName,
            shortName: shortName,
            animationsEnabled: true
        )
        XCTAssertEqual(state.phase, .scrolling(fullName: fullName, shortName: shortName))

        state.completeScroll()
        state.present(
            areaID: .forgottenShallowDepths,
            fullName: fullName,
            shortName: shortName,
            animationsEnabled: false
        )
        state.present(
            areaID: .forgottenShallowDepths,
            fullName: fullName,
            shortName: shortName,
            animationsEnabled: true
        )
        XCTAssertEqual(state.phase, .settled(shortName: shortName))
    }

    func testHoverRejectsTwoPointNineNineNineSecondsAndEarlyLeaveResetsDuration() {
        var state = settledState()

        XCTAssertFalse(state.advanceHover(
            by: 2.999,
            inside: true,
            interactive: true,
            animationsEnabled: true
        ))
        XCTAssertFalse(state.advanceHover(
            by: 0,
            inside: false,
            interactive: true,
            animationsEnabled: true
        ))
        XCTAssertFalse(state.advanceHover(
            by: 2.999,
            inside: true,
            interactive: true,
            animationsEnabled: true
        ))
        XCTAssertTrue(state.advanceHover(
            by: 0.001,
            inside: true,
            interactive: true,
            animationsEnabled: true
        ))
    }

    func testInteractiveHoverReplaysOnceAfterThreeSecondsAndRequiresReentry() {
        var state = presentedState()
        state.completeScroll()
        XCTAssertFalse(state.advanceHover(
            by: 2.999,
            inside: true,
            interactive: true,
            animationsEnabled: true
        ))
        XCTAssertTrue(state.advanceHover(
            by: 0.001,
            inside: true,
            interactive: true,
            animationsEnabled: true
        ))
        state.completeScroll()
        XCTAssertFalse(state.advanceHover(
            by: 3,
            inside: true,
            interactive: true,
            animationsEnabled: true
        ))
        _ = state.advanceHover(
            by: 0,
            inside: false,
            interactive: true,
            animationsEnabled: true
        )
        XCTAssertTrue(state.advanceHover(
            by: 3,
            inside: true,
            interactive: true,
            animationsEnabled: true
        ))
    }

    func testPassiveHoverNeverReplaysAndDoesNotAccumulateTime() {
        var state = settledState()

        XCTAssertFalse(state.advanceHover(
            by: 3,
            inside: true,
            interactive: false,
            animationsEnabled: true
        ))
        XCTAssertFalse(state.advanceHover(
            by: 2.999,
            inside: true,
            interactive: true,
            animationsEnabled: true
        ))
        XCTAssertEqual(state.phase, .settled(shortName: shortName))
    }

    private func presentedState() -> AreaTitleMarqueeState {
        var state = AreaTitleMarqueeState()
        state.present(
            areaID: .forgottenShallowDepths,
            fullName: fullName,
            shortName: shortName,
            animationsEnabled: true
        )
        return state
    }

    private func settledState() -> AreaTitleMarqueeState {
        var state = presentedState()
        state.completeScroll()
        return state
    }
}
