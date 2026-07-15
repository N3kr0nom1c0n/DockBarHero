import XCTest
@testable import DockBarHero

final class ManagementNavigationTests: XCTestCase {
    func testRoutesIncludeDeferredDestinations() {
        XCTAssertEqual(ManagementRoute.allCases, [
            .overview, .inventory, .book, .abilities, .skills, .shop, .settings
        ])
    }

    func testRoutesHaveStableTitlesAndSymbols() {
        XCTAssertEqual(ManagementRoute.overview.title, "Overview")
        XCTAssertEqual(ManagementRoute.inventory.title, "Inventory")
        XCTAssertEqual(ManagementRoute.book.title, "Book")
        XCTAssertEqual(ManagementRoute.abilities.title, "Abilities")
        XCTAssertEqual(ManagementRoute.skills.title, "Skills")
        XCTAssertEqual(ManagementRoute.shop.title, "Shop")
        XCTAssertEqual(ManagementRoute.settings.title, "Settings")
        XCTAssertEqual(ManagementRoute.overview.systemImage, "gauge.with.dots.needle.67percent")
        XCTAssertEqual(ManagementRoute.inventory.systemImage, "shippingbox")
        XCTAssertEqual(ManagementRoute.book.systemImage, "book.pages")
        XCTAssertEqual(ManagementRoute.abilities.systemImage, "bolt.circle")
        XCTAssertEqual(ManagementRoute.skills.systemImage, "point.3.connected.trianglepath.dotted")
        XCTAssertEqual(ManagementRoute.shop.systemImage, "storefront")
        XCTAssertEqual(ManagementRoute.settings.systemImage, "gearshape")
    }

    func testRouteIdentifiersAreStableRawValues() {
        XCTAssertEqual(ManagementRoute.overview.id, "overview")
        XCTAssertEqual(ManagementRoute.inventory.id, "inventory")
        XCTAssertEqual(ManagementRoute.settings.id, "settings")
    }
}
