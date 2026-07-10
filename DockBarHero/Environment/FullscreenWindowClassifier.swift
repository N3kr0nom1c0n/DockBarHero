import AppKit
import CoreGraphics

struct WindowSnapshot: Equatable {
    let ownerPID: pid_t
    let layer: Int
    let bounds: CGRect
    let isOnScreen: Bool
    let alpha: CGFloat

    init(
        ownerPID: pid_t,
        layer: Int,
        bounds: CGRect,
        isOnScreen: Bool,
        alpha: CGFloat = 1
    ) {
        self.ownerPID = ownerPID
        self.layer = layer
        self.bounds = bounds
        self.isOnScreen = isOnScreen
        self.alpha = alpha
    }
}

struct FullscreenWindowClassifier {
    private let tolerance: CGFloat = 2

    func isFullscreen(
        frontmostPID: pid_t,
        ownPID: pid_t,
        screenFrame: CGRect,
        windows: [WindowSnapshot]
    ) -> Bool {
        guard frontmostPID != ownPID else { return false }

        let frontmostWindows = windows.filter { $0.ownerPID == frontmostPID && $0.isOnScreen }
        let opaqueMainWindows = frontmostWindows.filter(isOpaqueMainWindow)

        if opaqueMainWindows.contains(where: { matches($0.bounds, screenFrame) }) {
            return true
        }

        let transparentCompanions = frontmostWindows.filter { $0.alpha <= 0.01 }
        return opaqueMainWindows.contains { mainWindow in
            transparentCompanions.contains { companion in
                isTopCompanionTopology(
                    main: mainWindow.bounds,
                    companion: companion.bounds,
                    displayBounds: screenFrame
                )
            }
        }
    }

    private func isOpaqueMainWindow(_ window: WindowSnapshot) -> Bool {
        window.layer == 0 && window.alpha >= 0.99
    }

    private func isTopCompanionTopology(
        main: CGRect,
        companion: CGRect,
        displayBounds: CGRect
    ) -> Bool {
        matches(companion.minX, displayBounds.minX)
            && matches(companion.minY, displayBounds.minY)
            && matches(companion.width, displayBounds.width)
            && matches(main.minX, displayBounds.minX)
            && matches(main.width, displayBounds.width)
            && matches(main.minY, companion.maxY)
            && matches(main.maxY, displayBounds.maxY)
            && tilesDisplay(main, companion, displayBounds: displayBounds)
    }

    private func tilesDisplay(_ first: CGRect, _ second: CGRect, displayBounds: CGRect) -> Bool {
        let union = first.union(second)
        let combinedArea = first.width * first.height + second.width * second.height
        let displayArea = displayBounds.width * displayBounds.height
        let areaTolerance = tolerance * (displayBounds.width + displayBounds.height)

        return matches(union, displayBounds)
            && abs(combinedArea - displayArea) <= areaTolerance
    }

    private func matches(_ first: CGRect, _ second: CGRect) -> Bool {
        matches(first.minX, second.minX)
            && matches(first.minY, second.minY)
            && matches(first.width, second.width)
            && matches(first.height, second.height)
    }

    private func matches(_ first: CGFloat, _ second: CGFloat) -> Bool {
        abs(first - second) <= tolerance
    }
}

@MainActor
protocol EnvironmentEvaluating: AnyObject {
    func currentVisibility() -> EnvironmentVisibility?
}

@MainActor
final class WorkspaceEnvironmentEvaluator: EnvironmentEvaluating {
    private let classifier = FullscreenWindowClassifier()

    func currentVisibility() -> EnvironmentVisibility? {
        guard let screen = NSScreen.screens.first,
              let app = NSWorkspace.shared.frontmostApplication,
              let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }

        let displayBounds = CGDisplayBounds(CGDirectDisplayID(screenNumber.uint32Value))
        guard !displayBounds.isNull, !displayBounds.isEmpty else { return nil }

        guard let rawWindows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        let windows = rawWindows.compactMap(Self.snapshot)
        let fullscreen = classifier.isFullscreen(
            frontmostPID: app.processIdentifier,
            ownPID: ProcessInfo.processInfo.processIdentifier,
            screenFrame: displayBounds,
            windows: windows
        )
        return fullscreen ? .fullscreen : .normalSpace
    }

    private static func snapshot(_ info: [String: Any]) -> WindowSnapshot? {
        guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
              let layer = info[kCGWindowLayer as String] as? Int,
              let boundsDictionary = info[kCGWindowBounds as String] as? [String: Any],
              let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary),
              let alpha = info[kCGWindowAlpha as String] as? NSNumber else {
            return nil
        }
        let isOnScreen = info[kCGWindowIsOnscreen as String] as? Bool ?? false
        return WindowSnapshot(
            ownerPID: ownerPID,
            layer: layer,
            bounds: bounds,
            isOnScreen: isOnScreen,
            alpha: CGFloat(alpha.doubleValue)
        )
    }
}
