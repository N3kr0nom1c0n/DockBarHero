import SwiftUI

struct LorePageView: View {
    let page: ResolvedLorePage
    let isBookOpen: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var frames: [CGImage] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                artwork
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(.black.opacity(0.45), lineWidth: 2))
                    .accessibilityLabel(page.accessibilityDescription)

                Text(page.title)
                    .font(.system(size: 23, weight: .black, design: .serif))
                Text(page.body)
                    .font(.system(size: 15, design: .serif))
                    .lineSpacing(4)
                    .textSelection(.enabled)
            }
            .padding(20)
        }
        .background(Color(red: 0.96, green: 0.89, blue: 0.72))
        .task(id: page.spriteSheetName) {
            frames = (try? LoreSpriteSheet.frames(named: page.spriteSheetName, frameCount: page.frameCount)) ?? []
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if frames.isEmpty {
            ZStack {
                Color.black.opacity(0.86)
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.largeTitle)
                    Text("THE ILLUSTRATOR HAS BEEN EATEN")
                        .font(.caption.bold())
                }
                .foregroundStyle(.white.opacity(0.8))
            }
        } else if reduceMotion || !isBookOpen || frames.count == 1 {
            frameImage(frames[0])
        } else {
            TimelineView(.animation(minimumInterval: Double(page.frameDurationMilliseconds) / 1_000)) { context in
                let duration = Double(page.frameDurationMilliseconds) / 1_000
                let index = Int(context.date.timeIntervalSinceReferenceDate / duration) % frames.count
                frameImage(frames[index])
            }
        }
    }

    private func frameImage(_ image: CGImage) -> some View {
        Image(decorative: image, scale: 1)
            .resizable()
            .scaledToFit()
    }
}
