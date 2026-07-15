import SwiftUI

struct BookVolumePotentiometer: View {
    let detent: Int
    let onChange: (Int) -> Void
    @State private var dragStart: Int?

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                ForEach(0...10, id: \.self) { tick in
                    Text("\(tick)")
                        .font(.system(size: 8, weight: tick == detent ? .bold : .regular, design: .monospaced))
                        .foregroundStyle(tick == detent ? Color.primary : Color.secondary)
                        .offset(y: -37)
                        .rotationEffect(.degrees(Double(tick - 5) * 24))
                }

                Circle()
                    .fill(.brown.gradient)
                    .overlay(Circle().stroke(.black.opacity(0.5), lineWidth: 2))
                    .frame(width: 54, height: 54)
                    .shadow(radius: 2, y: 1)

                Capsule()
                    .fill(.yellow.opacity(0.9))
                    .frame(width: 4, height: 21)
                    .offset(y: -12)
                    .rotationEffect(.degrees(Double(detent - 5) * 24))
            }
            .frame(width: 92, height: 82)

            Text("VOLUME-ISH")
                .font(.system(size: 8, weight: .black, design: .rounded))
                .tracking(1)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    let start = dragStart ?? detent
                    if dragStart == nil { dragStart = detent }
                    set(start - Int((value.translation.height / 12).rounded()))
                }
                .onEnded { _ in dragStart = nil }
        )
        .accessibilityElement()
        .accessibilityLabel("Book volume")
        .accessibilityValue(BookVolumeMapping.accessibilityValue(for: detent))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: set(detent + 1)
            case .decrement: set(detent - 1)
            @unknown default: break
            }
        }
    }

    private func set(_ proposed: Int) {
        let value = min(max(proposed, 0), 10)
        guard value != detent else { return }
        onChange(value)
    }
}
