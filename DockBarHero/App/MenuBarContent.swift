import AppKit
import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var model: AppModel
    let send: (OverlayAction) -> Void

    var body: some View {
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
