import CoreGraphics

enum LoreBookLayout {
    enum Mode: Equatable {
        case spread
        case singlePage
    }

    struct Spread: Equatable {
        let leftIndex: Int?
        let rightIndex: Int
    }

    struct PageRegions: Equatable {
        let artworkHeight: CGFloat
        let dividerHeight: CGFloat
        let captionHeight: CGFloat
    }

    static let minimumSpreadWidth: CGFloat = 720

    static func mode(forContentWidth width: CGFloat) -> Mode {
        width >= minimumSpreadWidth ? .spread : .singlePage
    }

    static func spread(pageCount: Int, currentIndex: Int) -> Spread? {
        guard pageCount > 0, (0..<pageCount).contains(currentIndex) else { return nil }
        let nextIndex = currentIndex + 1
        return Spread(
            leftIndex: nextIndex < pageCount ? nextIndex : nil,
            rightIndex: currentIndex
        )
    }

    static func captionHeight(forPageHeight height: CGFloat) -> CGFloat {
        min(190, max(150, height * 0.36))
    }

    static func pageRegions(forPageHeight height: CGFloat, dividerHeight: CGFloat) -> PageRegions {
        let safeHeight = max(0, height)
        let safeDividerHeight = min(max(0, dividerHeight), safeHeight)
        let captionHeight = min(
            Self.captionHeight(forPageHeight: safeHeight),
            safeHeight - safeDividerHeight
        )
        return PageRegions(
            artworkHeight: safeHeight - safeDividerHeight - captionHeight,
            dividerHeight: safeDividerHeight,
            captionHeight: captionHeight
        )
    }
}
