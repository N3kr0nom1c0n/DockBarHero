import SwiftUI

struct BookReactionBubble: View {
    let text: String

    var body: some View {
        if !text.isEmpty {
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded).italic())
                .foregroundStyle(Color.black)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: 320, alignment: .leading)
                .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                .allowsHitTesting(false)
                .accessibilityLabel("The Book says: \(text)")
        }
    }
}
