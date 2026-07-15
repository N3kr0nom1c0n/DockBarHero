import Foundation

struct AreaTitleMarqueeState: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        case hidden
        case scrolling(fullName: String, shortName: String)
        case settled(shortName: String)
    }

    private(set) var areaID: AreaID?
    private(set) var phase: Phase = .hidden
    private var fullName = ""
    private var shortName = ""
    private var continuousHoverDuration: TimeInterval = 0
    private var requiresPointerExit = false
    private var hasCompletedInitialScroll = false

    mutating func present(
        areaID: AreaID,
        fullName: String,
        shortName: String,
        animationsEnabled: Bool
    ) {
        if self.areaID == areaID {
            if !animationsEnabled {
                phase = .settled(shortName: self.shortName)
                continuousHoverDuration = 0
            } else if !hasCompletedInitialScroll {
                phase = .scrolling(fullName: self.fullName, shortName: self.shortName)
            }
            return
        }

        self.areaID = areaID
        self.fullName = fullName
        self.shortName = shortName
        continuousHoverDuration = 0
        requiresPointerExit = false
        hasCompletedInitialScroll = false
        phase = animationsEnabled
            ? .scrolling(fullName: fullName, shortName: shortName)
            : .settled(shortName: shortName)
    }

    mutating func hide() {
        areaID = nil
        phase = .hidden
        fullName = ""
        shortName = ""
        continuousHoverDuration = 0
        requiresPointerExit = false
        hasCompletedInitialScroll = false
    }

    mutating func completeScroll() {
        guard case let .scrolling(_, shortName) = phase else { return }
        phase = .settled(shortName: shortName)
        continuousHoverDuration = 0
        hasCompletedInitialScroll = true
    }

    @discardableResult
    mutating func advanceHover(
        by duration: TimeInterval,
        inside: Bool,
        interactive: Bool,
        animationsEnabled: Bool
    ) -> Bool {
        if !inside {
            continuousHoverDuration = 0
            requiresPointerExit = false
            return false
        }

        guard interactive, animationsEnabled else {
            continuousHoverDuration = 0
            if !animationsEnabled, case .scrolling = phase {
                phase = .settled(shortName: shortName)
            }
            return false
        }
        guard hasCompletedInitialScroll,
              !requiresPointerExit,
              case .settled = phase else { return false }

        continuousHoverDuration += max(0, duration)
        guard continuousHoverDuration >= 3 else { return false }

        continuousHoverDuration = 0
        requiresPointerExit = true
        phase = .scrolling(fullName: fullName, shortName: shortName)
        return true
    }
}
