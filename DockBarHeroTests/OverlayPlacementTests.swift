import CoreGraphics
import XCTest
@testable import DockBarHero

final class OverlayPlacementTests: XCTestCase {
    private let calculator = OverlayPlacementCalculator()

    func testCalculatesBalancedRailAboveVisibleDock() throws {
        let screen = ScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 1_728, height: 1_117),
            visibleFrame: CGRect(x: 0, y: 74, width: 1_728, height: 1_018),
            dockMode: .visibleBottom
        )

        let frame = try XCTUnwrap(calculator.frame(for: screen))

        XCTAssertEqual(frame.width, 1_140.48, accuracy: 0.001)
        XCTAssertEqual(frame.height, 96)
        XCTAssertEqual(frame.midX, 864, accuracy: 0.001)
        XCTAssertEqual(frame.minY, 82)
    }

    func testUsesDisplayBottomForAutoHiddenDock() throws {
        let screen = ScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 1_728, height: 1_117),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_728, height: 1_117),
            dockMode: .autoHidden
        )

        let frame = try XCTUnwrap(calculator.frame(for: screen))

        XCTAssertEqual(frame.minY, 8)
    }

    func testNeverExceedsNarrowScreen() throws {
        let screen = ScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 600, height: 500),
            visibleFrame: CGRect(x: 0, y: 0, width: 600, height: 500),
            dockMode: .autoHidden
        )

        XCTAssertEqual(try XCTUnwrap(calculator.frame(for: screen)).width, 600)
    }

    func testClampsWideScreenToMaximum() throws {
        let screen = ScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 3_000, height: 1_500),
            visibleFrame: CGRect(x: 0, y: 0, width: 3_000, height: 1_500),
            dockMode: .autoHidden
        )

        let frame = try XCTUnwrap(calculator.frame(for: screen))

        XCTAssertEqual(frame.width, 1_400)
        XCTAssertEqual(frame.minX, 800)
    }

    func testResolverRetainsLastValidFrame() throws {
        var resolver = PlacementResolver()
        let valid = ScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
            dockMode: .autoHidden
        )

        let first = try XCTUnwrap(resolver.resolve(valid))
        let invalid = ScreenGeometry(frame: .zero, visibleFrame: .zero, dockMode: .autoHidden)

        XCTAssertEqual(resolver.resolve(invalid), first)
    }
}
