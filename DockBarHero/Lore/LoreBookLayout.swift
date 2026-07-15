import CoreGraphics

enum LoreBookLayout {
    enum ReactionRegion: Equatable {
        case reservedHeader
    }

    enum ReactionArrangement: Equatable {
        case inline
        case stacked
    }

    struct ReactionPolicy: Equatable {
        let region: ReactionRegion
        let arrangement: ReactionArrangement
        let maximumBubbleWidth: CGFloat
    }

    enum Mode: Equatable {
        case spread
        case singlePage
    }

    struct Spread: Equatable {
        let leftIndex: Int?
        let rightIndex: Int
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

    static func pageCanvasInsets(forPageWidth width: CGFloat) -> CGFloat {
        width < 420 ? 8 : 12
    }

    static func panelGutter(forPageWidth width: CGFloat) -> CGFloat {
        min(8, max(5, (width * 0.015).rounded()))
    }

    static func usesPageCallout(characterCount: Int, panelWidth: CGFloat) -> Bool {
        panelWidth < 180 && characterCount > 55
    }

    static func reactionPolicy(forContentWidth width: CGFloat) -> ReactionPolicy {
        if width >= 760 {
            return ReactionPolicy(
                region: .reservedHeader,
                arrangement: .inline,
                maximumBubbleWidth: 320
            )
        }
        return ReactionPolicy(
            region: .reservedHeader,
            arrangement: .stacked,
            maximumBubbleWidth: min(420, max(240, width - 48))
        )
    }
}
