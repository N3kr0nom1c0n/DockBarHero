import XCTest
@testable import DockBarHero

final class BookVolumePotentiometerTests: XCTestCase {
    func testAccessibleVolumeIsHonestWhileNumbersAreReversed() {
        XCTAssertEqual(BookVolumeMapping.gain(for: 0), 1.0, accuracy: 0.000_1)
        XCTAssertEqual(BookVolumeMapping.gain(for: 5), 0.55, accuracy: 0.000_1)
        XCTAssertEqual(BookVolumeMapping.gain(for: 10), 0.1, accuracy: 0.000_1)
        XCTAssertEqual(BookVolumeMapping.accessibilityValue(for: 0), "100 percent, lower numbers are louder")
        XCTAssertEqual(BookVolumeMapping.accessibilityValue(for: 10), "10 percent, lower numbers are louder")
    }
}
