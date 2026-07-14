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
        VStack(spacing: 0) {
            header
            Divider()
            if model.lorePages.isEmpty {
                ContentUnavailableView("No Pages Yet", systemImage: "book.closed")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ViewThatFits(in: .horizontal) {
                    twoPageSpread
                    singlePage
                }
            }
            Divider()
            controls
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
            if !controller.reactionText.isEmpty {
                Text(controller.reactionText)
                    .font(.caption.italic())
                    .padding(8)
                    .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.black)
                    .accessibilityLabel("The Book says: \(controller.reactionText)")
            }
        }
        .padding(12)
        .background(Color(red: 0.88, green: 0.76, blue: 0.52))
    }

    private var twoPageSpread: some View {
        HStack(spacing: 3) {
            if model.lorePages.indices.contains(currentIndex + 1) {
                page(model.lorePages[currentIndex + 1])
            } else {
                Color(red: 0.93, green: 0.85, blue: 0.68)
            }
            page(model.lorePages[currentIndex])
        }
        .frame(minWidth: 720, minHeight: 390)
    }

    private var singlePage: some View {
        page(model.lorePages[currentIndex])
            .frame(minWidth: 360, minHeight: 390)
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
            Button("Previous ▶") { select(index: currentIndex - 1) }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(currentIndex == 0)

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
    }

    private func select(index: Int) {
        guard model.lorePages.indices.contains(index) else { return }
        controller.select(model.lorePages[index].id)
    }
}
