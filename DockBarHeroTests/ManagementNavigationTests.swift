import XCTest
@testable import DockBarHero

final class ManagementNavigationTests: XCTestCase {
    func testRoutesHaveStableTitlesAndSymbols() {
        XCTAssertEqual(ManagementRoute.allCases, [.overview, .inventory, .settings])
        XCTAssertEqual(ManagementRoute.overview.title, "Overview")
        XCTAssertEqual(ManagementRoute.inventory.title, "Inventory")
        XCTAssertEqual(ManagementRoute.settings.title, "Settings")
        XCTAssertEqual(ManagementRoute.overview.systemImage, "gauge.with.dots.needle.67percent")
        XCTAssertEqual(ManagementRoute.inventory.systemImage, "shippingbox")
        XCTAssertEqual(ManagementRoute.settings.systemImage, "gearshape")
    }

    func testRouteIdentifiersAreStableRawValues() {
        XCTAssertEqual(ManagementRoute.overview.id, "overview")
        XCTAssertEqual(ManagementRoute.inventory.id, "inventory")
        XCTAssertEqual(ManagementRoute.settings.id, "settings")
    }
}
