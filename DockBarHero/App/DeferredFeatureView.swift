import SwiftUI

struct DeferredFeatureView: View {
    let title: String
    let message: String
    var gold: Int64?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "hammer")
        } description: {
            VStack(spacing: 8) {
                if let gold {
                    Text("Gold: \(gold)")
                }
                Text(message)
            }
        }
        .navigationTitle(title)
    }
}
