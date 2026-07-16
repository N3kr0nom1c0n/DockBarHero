import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var confirmation = ""
    @State private var isResetting = false
    @State private var resetError: String?

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
            LoreSettingsSection(model: model)
            Section("Rail Appearance") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Heroes and enemies")
                        Spacer()
                        Text("\(model.appSettings.actorScalePercent)%")
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(model.appSettings.actorScalePercent) },
                            set: { model.updateActorScalePercent(Int($0.rounded())) }
                        ),
                        in: 75...140,
                        step: 1
                    )
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Rail text")
                        Spacer()
                        Text("\(model.appSettings.railTextScalePercent)%")
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(model.appSettings.railTextScalePercent) },
                            set: { model.updateRailTextScalePercent(Int($0.rounded())) }
                        ),
                        in: 85...130,
                        step: 1
                    )
                }
            }
            Section("Danger Zone") {
                Text("Start New Game replaces heroes, XP, gold, frontier, inventory, equipment, and unlocks.")
                    .foregroundStyle(.secondary)
                Text("Type GAME OVER MAN! to confirm.")
                    .font(.caption)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Confirmation phrase")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(
                        "Confirmation phrase",
                        text: $confirmation,
                        prompt: Text("GAME OVER MAN!")
                    )
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                    .frame(maxWidth: 360)
                }
                Button("Start New Game", role: .destructive) {
                    isResetting = true
                    resetError = nil
                    Task { @MainActor in
                        do {
                            try await model.startNewGame()
                        } catch {
                            resetError = String(describing: error)
                            isResetting = false
                        }
                    }
                }
                .disabled(
                    isResetting ||
                    !ManagementFormat.isNewGameConfirmationValid(confirmation)
                )
                if let resetError {
                    Text(resetError).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}
