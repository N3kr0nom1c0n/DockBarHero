import AppKit
import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var model: AppModel
    let send: (OverlayAction) -> Void
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Management Window") {
            openWindow(id: "management")
            NSApplication.shared.activate()
        }
        Button(model.state.manualVisibility == .shown ? "Hide Rail" : "Show Rail") {
            send(.setManualVisibility(model.state.manualVisibility == .shown ? .hidden : .shown))
        }
        Button(model.state.animationMode == .running ? "Pause Animation" : "Resume Animation") {
            send(.setAnimationMode(model.state.animationMode == .running ? .paused : .running))
        }
        Button(model.state.inputMode == .passive ? "Enable Interaction" : "Disable Interaction") {
            send(.setInputMode(model.state.inputMode == .passive ? .interactive : .passive))
        }
        Divider()
        Button("Quit DockBarHero") {
            NSApplication.shared.terminate(nil)
        }
    }
}
