import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Toggle("Show overlay", isOn: Binding(
                get: { model.state.manualVisibility == .shown },
                set: { model.send(.setManualVisibility($0 ? .shown : .hidden)) }
            ))
            Toggle("Run animations", isOn: Binding(
                get: { model.state.animationMode == .running },
                set: { model.send(.setAnimationMode($0 ? .running : .paused)) }
            ))
            Toggle("Interactive mode", isOn: Binding(
                get: { model.state.inputMode == .interactive },
                set: { model.send(.setInputMode($0 ? .interactive : .passive)) }
            ))
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}
