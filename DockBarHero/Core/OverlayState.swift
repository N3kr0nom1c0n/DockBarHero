import Foundation

enum ManualVisibility: String, Codable, Equatable, Sendable {
    case shown
    case hidden
}

enum EnvironmentVisibility: Equatable, Sendable {
    case normalSpace
    case fullscreen
}

enum AnimationMode: String, Codable, Equatable, Sendable {
    case running
    case paused
}

enum InputMode: String, Codable, Equatable, Sendable {
    case passive
    case interactive
}

enum OverlayAction: Equatable {
    case setManualVisibility(ManualVisibility)
    case setEnvironmentVisibility(EnvironmentVisibility)
    case setAnimationMode(AnimationMode)
    case setInputMode(InputMode)
}

struct OverlayState: Equatable {
    var manualVisibility: ManualVisibility = .shown
    var environmentVisibility: EnvironmentVisibility = .normalSpace
    var animationMode: AnimationMode = .running
    var inputMode: InputMode = .passive

    var isEffectivelyVisible: Bool {
        manualVisibility == .shown && environmentVisibility == .normalSpace
    }

    var shouldAnimate: Bool {
        isEffectivelyVisible && animationMode == .running
    }

    var acceptsInput: Bool {
        isEffectivelyVisible && inputMode == .interactive
    }

    mutating func apply(_ action: OverlayAction) {
        switch action {
        case .setManualVisibility(let value):
            manualVisibility = value
        case .setEnvironmentVisibility(let value):
            environmentVisibility = value
        case .setAnimationMode(let value):
            animationMode = value
        case .setInputMode(let value):
            inputMode = value
        }
    }
}
