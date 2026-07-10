import AppKit
import CoreGraphics

struct WindowSnapshot: Equatable {
    let ownerPID: pid_t
    let layer: Int
    let bounds: CGRect
    let isOnScreen: Bool
}

struct FullscreenWindowClassifier {
    func isFullscreen(
        frontmostPID: pid_t,
        ownPID: pid_t,
        screenFrame: CGRect,
        windows: [WindowSnapshot]
    ) -> Bool {
        guard frontmostPID != ownPID else { return false }

        return windows.contains { window in
            window.ownerPID == frontmostPID
                && window.layer == 0
                && window.isOnScreen
                && abs(window.bounds.width - screenFrame.width) <= 2
                && abs(window.bounds.height - screenFrame.height) <= 2
        }
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
              let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

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
            screenFrame: screen.frame,
            windows: windows
        )
        return fullscreen ? .fullscreen : .normalSpace
    }

    private static func snapshot(_ info: [String: Any]) -> WindowSnapshot? {
        guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
              let layer = info[kCGWindowLayer as String] as? Int,
              let boundsDictionary = info[kCGWindowBounds as String] as? [String: Any],
              let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary) else {
            return nil
        }
        let isOnScreen = info[kCGWindowIsOnscreen as String] as? Bool ?? false
        return WindowSnapshot(ownerPID: ownerPID, layer: layer, bounds: bounds, isOnScreen: isOnScreen)
    }
}
