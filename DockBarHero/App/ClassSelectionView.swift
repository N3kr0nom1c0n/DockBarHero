import SwiftUI

struct ClassSelectionView: View {
    @ObservedObject var model: AppModel
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Text("Choose Your First Hero")
                .font(.largeTitle.weight(.bold))
            Text("Your choice creates the new campaign after it is safely saved.")
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                classButton(.tank, title: "Tank", detail: "High health and defense")
                classButton(.dps, title: "DPS", detail: "Highest attack growth")
                classButton(.healer, title: "Healer", detail: "Balanced survival")
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        }
        .padding(40)
        .frame(minWidth: 720, minHeight: 520)
    }

    private func classButton(
        _ classID: HeroClassID,
        title: String,
        detail: String
    ) -> some View {
        Button {
            isSubmitting = true
            errorMessage = nil
            Task { @MainActor in
                do {
                    try await model.chooseStartingClass(classID)
                } catch {
                    errorMessage = String(describing: error)
                    isSubmitting = false
                }
            }
        } label: {
            VStack(spacing: 8) {
                Text(title).font(.title2.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            .frame(width: 170, height: 110)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isSubmitting)
    }
}
