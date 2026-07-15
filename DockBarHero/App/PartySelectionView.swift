import SwiftUI

struct PartySelectionView: View {
    @ObservedObject var model: AppModel
    let pending: PendingPartyUnlock
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Text("Choose Your Second Hero")
                .font(.largeTitle.weight(.bold))
            Text("Boss 25 rewards are saved. Combat remains paused until you choose.")
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                ForEach(pending.choices, id: \.self) { classID in
                    Button {
                        submit(classID)
                    } label: {
                        VStack(spacing: 8) {
                            Text(classID.displayName).font(.title2.weight(.semibold))
                            Text(classID.selectionDetail).font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(width: 190, height: 110)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmitting)
                    .accessibilityIdentifier("party-class-\(classID.rawValue)")
                }
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        }
        .padding(40)
        .frame(minWidth: 720, minHeight: 520)
    }

    private func submit(_ classID: HeroClassID) {
        isSubmitting = true
        errorMessage = nil
        Task { @MainActor in
            do {
                try await model.choosePartyClass(classID)
            } catch {
                errorMessage = String(describing: error)
                isSubmitting = false
            }
        }
    }
}

private extension HeroClassID {
    var selectionDetail: String {
        switch self {
        case .tank: "High health and defense"
        case .dps: "Highest attack growth"
        case .healer: "Balanced survival"
        }
    }
}
