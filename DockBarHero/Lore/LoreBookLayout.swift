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

    struct ControlsPadding: Equatable {
        let top: CGFloat
        let bottom: CGFloat
        let horizontal: CGFloat
    }

    static let minimumSpreadWidth: CGFloat = 720
    static let controlsPadding = ControlsPadding(top: 6, bottom: 12, horizontal: 14)

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
        // Compact manga balloons remain readable through roughly three short lines.
        // Keep both language variants attached until the copy truly needs page space;
        // otherwise a few censorship-rewrite characters can make a bubble teleport.
        panelWidth < 180 && characterCount > 64
    }

    static func attachedOverlayMaximumWidth(
        style: LoreTextOverlayStyle,
        panelWidth: CGFloat
    ) -> CGFloat {
        let availableWidth = max(40, panelWidth - 20)
        switch style {
        case .speech:
            return min(220, availableWidth)
        case .title, .narration:
            return min(240, availableWidth)
        case .soundEffect:
            return min(180, availableWidth)
        }
    }

    static func pageCalloutMaximumWidth(forCanvasWidth width: CGFloat) -> CGFloat {
        min(240, max(40, width - 24))
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

enum LoreMotionPanelPlayback {
    static func shouldAnimate(
        frameCount: Int,
        isBookOpen: Bool,
        applicationIsActive: Bool,
        reduceMotion: Bool
    ) -> Bool {
        frameCount > 1 && isBookOpen && applicationIsActive && !reduceMotion
    }
}
