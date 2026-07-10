import CoreGraphics
import Foundation

enum DockMode: Equatable {
    case visibleBottom
    case autoHidden
}

struct ScreenGeometry: Equatable {
    let frame: CGRect
    let visibleFrame: CGRect
    let dockMode: DockMode
}

struct OverlayPlacementPolicy: Equatable {
    let widthFraction: CGFloat
    let minimumWidth: CGFloat
    let maximumWidth: CGFloat
    let height: CGFloat
    let bottomOffset: CGFloat

    static let phaseZero = OverlayPlacementPolicy(
        widthFraction: 0.66,
        minimumWidth: 720,
        maximumWidth: 1_400,
        height: 96,
        bottomOffset: 8
    )
}

struct OverlayPlacementCalculator {
    let policy: OverlayPlacementPolicy

    init(policy: OverlayPlacementPolicy = .phaseZero) {
        self.policy = policy
    }

    func frame(for screen: ScreenGeometry) -> CGRect? {
        guard screen.frame.isFiniteAndPositive,
              screen.visibleFrame.isFiniteAndPositive,
              policy.height + policy.bottomOffset <= screen.frame.height else {
            return nil
        }

        let proposedWidth = screen.visibleFrame.width * policy.widthFraction
        let clampedWidth = min(max(proposedWidth, policy.minimumWidth), policy.maximumWidth)
        let width = min(clampedWidth, screen.visibleFrame.width)
        let x = screen.visibleFrame.midX - width / 2
        let baseY = screen.dockMode == .visibleBottom
            ? screen.visibleFrame.minY
            : screen.frame.minY

        return CGRect(
            x: x,
            y: baseY + policy.bottomOffset,
            width: width,
            height: policy.height
        )
    }
}

struct PlacementResolver {
    private var calculator = OverlayPlacementCalculator()
    private(set) var lastValidFrame: CGRect?

    mutating func resolve(_ screen: ScreenGeometry) -> CGRect? {
        guard let frame = calculator.frame(for: screen) else {
            return lastValidFrame
        }
        lastValidFrame = frame
        return frame
    }
}

private extension CGRect {
    var isFiniteAndPositive: Bool {
        origin.x.isFinite && origin.y.isFinite
            && width.isFinite && height.isFinite
            && width > 0 && height > 0
    }
}
