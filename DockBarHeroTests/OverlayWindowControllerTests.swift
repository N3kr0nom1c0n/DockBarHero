import AppKit
import XCTest
@testable import DockBarHero

@MainActor
final class OverlayWindowControllerTests: XCTestCase {
    func testPanelIsTransparentNonActivatingAndPassive() {
        let content = NSView(frame: CGRect(x: 0, y: 0, width: 800, height: 96))
        let controller = OverlayWindowController(contentView: content)
        let panel = controller.panel

        XCTAssertFalse(panel.isOpaque)
        XCTAssertEqual(panel.backgroundColor, .clear)
        XCTAssertFalse(panel.hasShadow)
        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(panel.collectionBehavior.contains(.stationary))
        XCTAssertTrue(panel.collectionBehavior.contains(.ignoresCycle))
    }

    func testControllerAppliesFrameInputAndVisibility() {
        let controller = OverlayWindowController(contentView: NSView())
        let frame = CGRect(x: 10, y: 20, width: 900, height: 96)

        controller.setFrame(frame)
        controller.setInputEnabled(true)
        controller.setVisible(false)

        XCTAssertEqual(controller.panel.frame, frame)
        XCTAssertFalse(controller.panel.ignoresMouseEvents)
        XCTAssertFalse(controller.panel.isVisible)
    }

    func testContentViewResizesWithPanel() {
        let content = NSView(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
        let controller = OverlayWindowController(contentView: content)
        let frame = CGRect(x: 10, y: 20, width: 900, height: 96)

        controller.setFrame(frame)
        controller.panel.layoutIfNeeded()

        XCTAssertEqual(content.frame.size, frame.size)
    }

    func testDockModeSnapshotRetainsFirstModeForScreen() {
        var snapshot = DockModeSnapshot()
        let screen = NSNumber(value: 1)

        XCTAssertEqual(snapshot.mode(for: screen, inferred: .visibleBottom), .visibleBottom)
        XCTAssertEqual(snapshot.mode(for: screen, inferred: .autoHidden), .visibleBottom)
        XCTAssertEqual(snapshot.mode(for: NSNumber(value: 2), inferred: .autoHidden), .autoHidden)
    }
}
