import XCTest
@testable import DockBarHero

final class LoreMangaLayoutTests: XCTestCase {
    func testTemplatesHaveExpectedPanelCountsAndUniqueSlots() {
        let expected: [LoreMangaLayoutID: Int] = [
            .cascadeFive: 5,
            .brokenSix: 6,
            .staggeredSix: 6,
            .shatteredSeven: 7
        ]

        for (id, count) in expected {
            let template = LoreMangaLayout.template(for: id)
            XCTAssertEqual(template.id, id)
            XCTAssertEqual(template.slots.count, count)
            XCTAssertEqual(Set(template.slots.map(\.id)).count, count)
        }
    }

    func testTemplatesUseExactDeterministicGeometryAndAlternatingClips() {
        let expectedFrames: [LoreMangaLayoutID: [LoreNormalizedRect]] = [
            .cascadeFive: [
                .init(x: 0.600, y: 0.015, width: 0.385, height: 0.290),
                .init(x: 0.420, y: 0.317, width: 0.565, height: 0.668),
                .init(x: 0.015, y: 0.015, width: 0.573, height: 0.290),
                .init(x: 0.015, y: 0.317, width: 0.393, height: 0.320),
                .init(x: 0.015, y: 0.649, width: 0.393, height: 0.336)
            ],
            .brokenSix: [
                .init(x: 0.640, y: 0.015, width: 0.345, height: 0.250),
                .init(x: 0.480, y: 0.277, width: 0.505, height: 0.708),
                .init(x: 0.015, y: 0.015, width: 0.613, height: 0.250),
                .init(x: 0.015, y: 0.277, width: 0.453, height: 0.220),
                .init(x: 0.015, y: 0.509, width: 0.453, height: 0.220),
                .init(x: 0.015, y: 0.741, width: 0.453, height: 0.244)
            ],
            .staggeredSix: [
                .init(x: 0.650, y: 0.015, width: 0.335, height: 0.220),
                .init(x: 0.440, y: 0.247, width: 0.545, height: 0.660),
                .init(x: 0.015, y: 0.015, width: 0.623, height: 0.220),
                .init(x: 0.015, y: 0.247, width: 0.413, height: 0.200),
                .init(x: 0.015, y: 0.459, width: 0.413, height: 0.200),
                .init(x: 0.015, y: 0.671, width: 0.413, height: 0.314)
            ],
            .shatteredSeven: [
                .init(x: 0.650, y: 0.015, width: 0.335, height: 0.220),
                .init(x: 0.440, y: 0.247, width: 0.545, height: 0.660),
                .init(x: 0.015, y: 0.015, width: 0.623, height: 0.220),
                .init(x: 0.015, y: 0.247, width: 0.413, height: 0.200),
                .init(x: 0.015, y: 0.459, width: 0.413, height: 0.200),
                .init(x: 0.227, y: 0.671, width: 0.201, height: 0.314),
                .init(x: 0.015, y: 0.671, width: 0.200, height: 0.314)
            ]
        ]
        let oddClip = [
            LoreNormalizedPoint(x: 0, y: 0),
            LoreNormalizedPoint(x: 1, y: 0),
            LoreNormalizedPoint(x: 0.94, y: 1),
            LoreNormalizedPoint(x: 0.06, y: 1)
        ]
        let evenClip = [
            LoreNormalizedPoint(x: 0.06, y: 0),
            LoreNormalizedPoint(x: 0.94, y: 0),
            LoreNormalizedPoint(x: 1, y: 1),
            LoreNormalizedPoint(x: 0, y: 1)
        ]

        for id in LoreMangaLayoutID.allCases {
            let template = LoreMangaLayout.template(for: id)
            XCTAssertEqual(template.slots.map(\.id), expectedFrames[id]!.indices.map { "slot\($0 + 1)" })
            XCTAssertEqual(template.slots.map(\.frame), expectedFrames[id])
            for (index, slot) in template.slots.enumerated() {
                XCTAssertEqual(slot.clipPolygon, index.isMultiple(of: 2) ? oddClip : evenClip)
                XCTAssertEqual(template.slot(id: slot.id), slot)
            }
            XCTAssertNil(template.slot(id: "missing"))
        }
    }

    func testSlotsStayInBoundsAndFramesDoNotOverlap() {
        for id in LoreMangaLayoutID.allCases {
            let slots = LoreMangaLayout.template(for: id).slots
            for slot in slots {
                XCTAssertTrue(slot.frame.isInsideUnitSquare)
                XCTAssertTrue(slot.clipPolygon.allSatisfy {
                    (0...1).contains($0.x) && (0...1).contains($0.y)
                })
            }
            for left in slots.indices {
                for right in slots.indices where right > left {
                    XCTAssertFalse(slots[left].frame.hasInteriorOverlap(with: slots[right].frame))
                }
            }
        }
    }

    func testSlotTwoIsTheDominantThirtyFiveToFortyFivePercentPanel() throws {
        for id in LoreMangaLayoutID.allCases {
            let template = LoreMangaLayout.template(for: id)
            let slotTwo = try XCTUnwrap(template.slot(id: "slot2"))
            let dominantArea = slotTwo.frame.width * slotTwo.frame.height

            XCTAssertTrue((0.35...0.45).contains(dominantArea))
            XCTAssertEqual(dominantArea, template.slots.map { $0.frame.width * $0.frame.height }.max())
        }
    }

    func testShatteredSevenSequentialSlotsFollowRightToLeftStoryLanes() throws {
        let template = LoreMangaLayout.template(for: .shatteredSeven)
        let slots = try (1...7).map { number in
            try XCTUnwrap(template.slot(id: "slot\(number)"))
        }

        let slot1 = slots[0].frame
        let slot2 = slots[1].frame
        let slot3 = slots[2].frame
        let slot4 = slots[3].frame
        let slot5 = slots[4].frame
        let slot6 = slots[5].frame
        let slot7 = slots[6].frame

        XCTAssertGreaterThan(slot1.x, slot3.x + slot3.width)
        XCTAssertLessThan(slot1.y + slot1.height, slot2.y)
        XCTAssertGreaterThan(slot2.x, slot4.x + slot4.width)
        XCTAssertGreaterThan(slot2.x, slot5.x + slot5.width)

        XCTAssertLessThan(slot3.y, slot4.y)
        XCTAssertLessThan(slot4.y, slot5.y)
        XCTAssertLessThan(slot5.y + slot5.height, slot6.y)

        XCTAssertEqual(slot6.y, slot7.y)
        XCTAssertGreaterThan(slot6.x, slot7.x + slot7.width)
    }
}
