import XCTest
@testable import DockBarHero

final class SimulationDurationTests: XCTestCase {
    func testConstructionOrderingAndPresentationConversionAreExact() {
        let oneMillisecond = try! XCTUnwrap(SimulationDuration.milliseconds(1))
        let oneSecond = try! XCTUnwrap(SimulationDuration.seconds(1))
        let oneAndHalfSeconds = try! XCTUnwrap(SimulationDuration.milliseconds(1_500))

        XCTAssertEqual(oneMillisecond.rawValue, 1_000_000)
        XCTAssertEqual(oneSecond.rawValue, 1_000_000_000)
        XCTAssertLessThan(oneMillisecond, oneSecond)
        XCTAssertEqual(oneAndHalfSeconds.timeInterval, 1.5)
    }

    func testCodableUsesOneExplicitScalarInt64() throws {
        let original = SimulationDuration(rawValue: -1)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SimulationDuration.self, from: encoded)

        XCTAssertEqual(String(decoding: encoded, as: UTF8.self), "-1")
        XCTAssertEqual(decoded, original)
    }

    func testCheckedConstructionRejectsMultiplicationOverflow() {
        XCTAssertNil(SimulationDuration.milliseconds(Int64.max))
        XCTAssertNil(SimulationDuration.seconds(Int64.max))
    }
}
