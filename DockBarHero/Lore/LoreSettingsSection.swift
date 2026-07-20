import SwiftUI

struct LoreSettingsSection: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Section("Manga Book") {
            Picker("Language", selection: Binding(
                get: { model.appSettings.loreLanguageMode },
                set: { model.updateLoreLanguage($0) }
            )) {
                Text("Unfiltered").tag(LoreLanguageMode.unfiltered)
                Text("Clean").tag(LoreLanguageMode.clean)
            }
            .pickerStyle(.segmented)

            Picker("Illustrations", selection: Binding(
                get: { model.appSettings.loreIllustrationMode },
                set: { model.updateLoreIllustration($0) }
            )) {
                Text("Safe").tag(LoreIllustrationMode.safe)
                Text("Adult").tag(LoreIllustrationMode.adult)
            }
            .pickerStyle(.segmented)

            Toggle("Spoken dialogue", isOn: Binding(
                get: { model.appSettings.spokenDialogueEnabled },
                set: { model.updateSpokenDialogue($0) }
            ))

            Toggle("Read newly unlocked pages", isOn: Binding(
                get: { model.appSettings.autoReadNewLorePages },
                set: { model.updateAutoReadNewLorePages($0) }
            ))
            .disabled(!model.appSettings.spokenDialogueEnabled)

            Text(LoreBookSpeechStatus.settingsExplanation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .confirmationDialog(
            "Enable adult manga illustrations?",
            isPresented: Binding(
                get: { model.isAdultIllustrationConfirmationPresented },
                set: { if !$0 { model.cancelAdultIllustrations() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Enable Adult Illustrations", role: .destructive) {
                model.confirmAdultIllustrations()
            }
            Button("Keep Safe Illustrations", role: .cancel) {
                model.cancelAdultIllustrations()
            }
        } message: {
            Text("This may show non-explicit adult nudity in unlocked lore pages. It does not change combat or language censorship.")
        }
    }
}
