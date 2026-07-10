import AppKit

@MainActor
protocol ScreenProviding: AnyObject {
    func currentGeometry() -> ScreenGeometry?
}

@MainActor
struct DockModeSnapshot {
    private var modes: [NSNumber: DockMode] = [:]

    mutating func mode(for screenNumber: NSNumber, inferred: DockMode) -> DockMode {
        if let stableMode = modes[screenNumber] {
            return stableMode
        }

        modes[screenNumber] = inferred
        return inferred
    }
}

@MainActor
final class AppKitScreenProvider: ScreenProviding {
    private var dockModeSnapshot = DockModeSnapshot()

    func currentGeometry() -> ScreenGeometry? {
        guard let screen = NSScreen.screens.first,
              let screenNumber = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
              ] as? NSNumber else {
            AppLog.placement.error("No target screen available")
            return nil
        }

        let inferredMode: DockMode = screen.visibleFrame.minY > screen.frame.minY + 1
            ? .visibleBottom
            : .autoHidden
        let dockMode = dockModeSnapshot.mode(for: screenNumber, inferred: inferredMode)

        return ScreenGeometry(
            frame: screen.frame,
            visibleFrame: screen.visibleFrame,
            dockMode: dockMode
        )
    }
}
