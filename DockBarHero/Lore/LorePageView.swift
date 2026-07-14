import SwiftUI

struct LorePageView: View {
    let page: ResolvedLorePage
    let isBookOpen: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var frames: [CGImage] = []

    var body: some View {
        GeometryReader { geometry in
            let regions = LoreBookLayout.pageRegions(
                forPageHeight: geometry.size.height,
                dividerHeight: 1
            )

            VStack(spacing: 0) {
                artwork
                    .frame(maxWidth: .infinity)
                    .frame(height: regions.artworkHeight)
                    .background(Color.black.opacity(0.9))
                    .clipped()
                    .accessibilityLabel(page.accessibilityDescription)

                Divider()
                    .frame(height: regions.dividerHeight)
                    .overlay(Color.black.opacity(0.35))

                caption
                    .frame(height: regions.captionHeight, alignment: .topLeading)
            }
            .background(Color(red: 0.96, green: 0.89, blue: 0.72))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.black.opacity(0.5), lineWidth: 2)
            )
        }
        .task(id: page.spriteSheetName) {
            frames = (try? LoreSpriteSheet.frames(named: page.spriteSheetName, frameCount: page.frameCount)) ?? []
        }
    }

    private var caption: some View {
        ViewThatFits(in: .vertical) {
            captionContent(titleSize: 22, bodySize: 15, spacing: 8, padding: 16)
            captionContent(titleSize: 19, bodySize: 13, spacing: 6, padding: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 0.98, green: 0.93, blue: 0.82))
        .foregroundStyle(Color(red: 0.12, green: 0.08, blue: 0.06))
        .textSelection(.enabled)
    }

    private func captionContent(
        titleSize: CGFloat,
        bodySize: CGFloat,
        spacing: CGFloat,
        padding: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            Text(page.title)
                .font(.system(size: titleSize, weight: .black, design: .serif))
                .fixedSize(horizontal: false, vertical: true)
            Text(page.body)
                .font(.system(size: bodySize, weight: .medium, design: .serif))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(padding)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
