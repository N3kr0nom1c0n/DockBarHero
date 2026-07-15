import Foundation

struct LoreNormalizedPoint: Equatable, Sendable {
    let x: CGFloat
    let y: CGFloat
}

struct LoreNormalizedRect: Equatable, Sendable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat

    var isInsideUnitSquare: Bool {
        x >= 0 && y >= 0 && x + width <= 1 && y + height <= 1
    }

    func hasInteriorOverlap(with other: Self) -> Bool {
        min(x + width, other.x + other.width) - max(x, other.x) > 0.0001 &&
            min(y + height, other.y + other.height) - max(y, other.y) > 0.0001
    }
}

struct LoreMangaPanelSlot: Equatable, Sendable {
    let id: String
    let frame: LoreNormalizedRect
    let clipPolygon: [LoreNormalizedPoint]
}

struct LoreMangaTemplate: Equatable, Sendable {
    let id: LoreMangaLayoutID
    let slots: [LoreMangaPanelSlot]

    func slot(id: String) -> LoreMangaPanelSlot? {
        slots.first { $0.id == id }
    }
}

enum LoreMangaLayout {
    static func template(for id: LoreMangaLayoutID) -> LoreMangaTemplate {
        let frames: [LoreNormalizedRect]
        switch id {
        case .cascadeFive:
            frames = [
                .init(x: 0.600, y: 0.015, width: 0.385, height: 0.290),
                .init(x: 0.420, y: 0.317, width: 0.565, height: 0.668),
                .init(x: 0.015, y: 0.015, width: 0.573, height: 0.290),
                .init(x: 0.015, y: 0.317, width: 0.393, height: 0.320),
                .init(x: 0.015, y: 0.649, width: 0.393, height: 0.336)
            ]
        case .brokenSix:
            frames = [
                .init(x: 0.640, y: 0.015, width: 0.345, height: 0.250),
                .init(x: 0.480, y: 0.277, width: 0.505, height: 0.708),
                .init(x: 0.015, y: 0.015, width: 0.613, height: 0.250),
                .init(x: 0.015, y: 0.277, width: 0.453, height: 0.220),
                .init(x: 0.015, y: 0.509, width: 0.453, height: 0.220),
                .init(x: 0.015, y: 0.741, width: 0.453, height: 0.244)
            ]
        case .staggeredSix:
            frames = [
                .init(x: 0.650, y: 0.015, width: 0.335, height: 0.220),
                .init(x: 0.440, y: 0.247, width: 0.545, height: 0.660),
                .init(x: 0.015, y: 0.015, width: 0.623, height: 0.220),
                .init(x: 0.015, y: 0.247, width: 0.413, height: 0.200),
                .init(x: 0.015, y: 0.459, width: 0.413, height: 0.200),
                .init(x: 0.015, y: 0.671, width: 0.413, height: 0.314)
            ]
        case .shatteredSeven:
            frames = [
                .init(x: 0.015, y: 0.015, width: 0.393, height: 0.200),
                .init(x: 0.420, y: 0.015, width: 0.565, height: 0.650),
                .init(x: 0.015, y: 0.227, width: 0.393, height: 0.200),
                .init(x: 0.015, y: 0.439, width: 0.393, height: 0.226),
                .init(x: 0.015, y: 0.677, width: 0.300, height: 0.308),
                .init(x: 0.327, y: 0.677, width: 0.318, height: 0.308),
                .init(x: 0.657, y: 0.677, width: 0.328, height: 0.308)
            ]
        }

        return LoreMangaTemplate(
            id: id,
            slots: frames.enumerated().map { index, frame in
                let slotNumber = index + 1
                return LoreMangaPanelSlot(
                    id: "slot\(slotNumber)",
                    frame: frame,
                    clipPolygon: slotNumber.isMultiple(of: 2) ? evenClip : oddClip
                )
            }
        )
    }

    private static let oddClip = [
        LoreNormalizedPoint(x: 0, y: 0),
        LoreNormalizedPoint(x: 1, y: 0),
        LoreNormalizedPoint(x: 0.94, y: 1),
        LoreNormalizedPoint(x: 0.06, y: 1)
    ]

    private static let evenClip = [
        LoreNormalizedPoint(x: 0.06, y: 0),
        LoreNormalizedPoint(x: 0.94, y: 0),
        LoreNormalizedPoint(x: 1, y: 1),
        LoreNormalizedPoint(x: 0, y: 1)
    ]
}
