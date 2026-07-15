import SwiftUI

struct LoreBookView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if let controller = model.loreReader as? LoreReaderController {
            LoreBookReaderView(model: model, controller: controller)
        } else {
            ContentUnavailableView(
                "The Book Is Sulking",
                systemImage: "book.closed",
                description: Text("Its dialogue catalog failed validation, which it insists is censorship.")
            )
        }
    }
}

private struct LoreBookReaderView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var controller: LoreReaderController
    @State private var arrowPointsWrongWay = true

    private var currentIndex: Int {
        guard let id = controller.currentPageID,
              let index = model.lorePages.firstIndex(where: { $0.id == id }) else { return 0 }
        return index
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                header
                    .frame(height: 62)
                Divider()

                if model.lorePages.isEmpty {
                    ContentUnavailableView("No Pages Yet", systemImage: "book.closed")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    GeometryReader { geometry in
                        readerContent(for: LoreBookLayout.mode(forContentWidth: geometry.size.width))
                    }
                    .layoutPriority(1)
                }

                Divider()
                controls
            }

            BookReactionBubble(text: controller.reactionText)
                .padding(.top, 74)
                .padding(.trailing, 18)
        }
        .background(Color(red: 0.20, green: 0.08, blue: 0.06))
        .task {
            arrowPointsWrongWay = true
            try? await Task.sleep(for: .milliseconds(900))
            arrowPointsWrongWay = false
            controller.arrowCorrected()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("A COMPLETELY ACCURATE HISTORY")
                    .font(.headline.smallCaps())
                Text("Read right to left. Unless the arrow has mysteriously betrayed you.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: arrowPointsWrongWay ? "arrow.right.circle.fill" : "arrow.left.circle.fill")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(arrowPointsWrongWay ? .red : .black)
                .accessibilityLabel(arrowPointsWrongWay ? "Misleading reading arrow pointing right" : "Corrected reading arrow pointing left")
        }
        .padding(12)
        .background(Color(red: 0.88, green: 0.76, blue: 0.52))
    }

    private var twoPageSpread: some View {
        Group {
            if let spread = LoreBookLayout.spread(
                pageCount: model.lorePages.count,
                currentIndex: currentIndex
            ) {
                HStack(spacing: 3) {
                    if let leftIndex = spread.leftIndex {
                        page(model.lorePages[leftIndex])
                    } else {
                        Color(red: 0.93, green: 0.85, blue: 0.68)
                    }
                    page(model.lorePages[spread.rightIndex])
                }
            }
        }
        .padding(10)
    }

    private var singlePage: some View {
        page(model.lorePages[currentIndex])
            .frame(maxWidth: 560)
            .padding(10)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func readerContent(for mode: LoreBookLayout.Mode) -> some View {
        switch mode {
        case .spread:
            twoPageSpread
        case .singlePage:
            singlePage
        }
    }

    private func page(_ page: ResolvedLorePage) -> some View {
        LorePageView(page: page, isBookOpen: controller.isOpen)
            .onTapGesture { controller.select(page.id) }
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button("Next ◀") { select(index: currentIndex + 1) }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(currentIndex + 1 >= model.lorePages.count)
                .accessibilityLabel("Next Page")
            Button("Previous ▶") { select(index: currentIndex - 1) }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(currentIndex == 0)
                .accessibilityLabel("Previous Page")

            Divider().frame(height: 32)
            Button("Replay", systemImage: "speaker.wave.2") { controller.replay() }
                .disabled(!model.appSettings.spokenDialogueEnabled)
            Button("Skip", systemImage: "forward.end") { controller.skip() }
                .disabled(!model.appSettings.spokenDialogueEnabled)

            Spacer()
            BookVolumePotentiometer(detent: model.appSettings.bookVolumeDetent) { model.updateBookVolume($0) }
                .frame(width: 100)
        }
        .buttonStyle(.bordered)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color(red: 0.78, green: 0.61, blue: 0.36))
        .frame(minHeight: 92)
    }

    private func select(index: Int) {
        guard model.lorePages.indices.contains(index) else { return }
        controller.select(model.lorePages[index].id)
    }
}
