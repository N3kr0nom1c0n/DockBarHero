import AppKit

@MainActor
protocol OverlayWindowControlling: AnyObject {
    func setFrame(_ frame: CGRect)
    func setVisible(_ isVisible: Bool)
    func setInputEnabled(_ isEnabled: Bool)
}

@MainActor
final class OverlayWindowController: OverlayWindowControlling {
    let panel: OverlayPanel

    init(contentView: NSView) {
        contentView.autoresizingMask = [.width, .height]
        panel = OverlayPanel(
            contentRect: contentView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = contentView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        AppLog.overlay.info("Overlay panel created")
    }

    func setFrame(_ frame: CGRect) {
        panel.setFrame(frame, display: true)
        AppLog.placement.debug("Applied overlay frame x=\(frame.minX) y=\(frame.minY) w=\(frame.width) h=\(frame.height)")
    }

    func setVisible(_ isVisible: Bool) {
        if isVisible {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    func setInputEnabled(_ isEnabled: Bool) {
        panel.ignoresMouseEvents = !isEnabled
    }
}
