import SwiftUI

struct LorePageView: View {
    let page: ResolvedLorePage
    let isBookOpen: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var motionFrames: [CGImage] = []
    @State private var contextCells: [CGImage] = []
    @State private var didLoadContext = false

    var body: some View {
        GeometryReader { geometry in
            let inset = LoreBookLayout.pageCanvasInsets(forPageWidth: geometry.size.width)
            let canvasSize = CGSize(
                width: max(0, geometry.size.width - inset * 2),
                height: max(0, geometry.size.height - inset * 2)
            )

            Group {
                if !didLoadContext {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Loading manga page")
                } else if hasRequiredContextCells {
                    mangaCanvas(size: canvasSize)
                } else {
                    missingArtworkDiagnostic
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .padding(inset)
            .background(Color(red: 0.96, green: 0.89, blue: 0.72))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.black.opacity(0.5), lineWidth: 2)
            )
        }
        .task(id: "\(page.spriteSheetName)|\(page.composition.contextSheetName)") {
            didLoadContext = false
            motionFrames = (try? LoreSpriteSheet.frames(
                named: page.spriteSheetName,
                frameCount: page.frameCount
            )) ?? []
            contextCells = (try? LoreContextSheet.cells(
                named: page.composition.contextSheetName
            )) ?? []
            didLoadContext = true
        }
    }

    private var hasRequiredContextCells: Bool {
        contextCells.count == 6 && page.composition.panels.allSatisfy { panel in
            panel.role != .still || panel.sourceCell.map(contextCells.indices.contains) == true
        }
    }

    private var missingArtworkDiagnostic: some View {
        ZStack {
            Color.black.opacity(0.86)
            VStack(spacing: 8) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.largeTitle)
                    .accessibilityHidden(true)
                Text("THE ILLUSTRATOR HAS BEEN EATEN")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(.white.opacity(0.8))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("The illustrator has been eaten. This manga page is unavailable.")
    }

    private func mangaCanvas(size: CGSize) -> some View {
        let template = LoreMangaLayout.template(for: page.composition.layoutID)
        let gutter = LoreBookLayout.panelGutter(forPageWidth: size.width)
        let panels = page.composition.panels.sorted { $0.readingOrder < $1.readingOrder }
        let visiblePanels = panels.filter {
            $0.role != .gag || $0.sourceCell.map(contextCells.indices.contains) == true
        }
        let visiblePanelIDs = Set(visiblePanels.map(\.id))

        return ZStack(alignment: .topLeading) {
            ForEach(visiblePanels, id: \.id) { panel in
                if let slot = template.slot(id: panel.slotID) {
                    let rect = panelRect(for: slot, canvasSize: size, gutter: gutter)
                    panelView(panel, slot: slot, rect: rect)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }
            }

            ForEach(page.composition.textOverlays, id: \.id) { overlay in
                if let panel = page.composition.panels.first(where: { $0.id == overlay.panelID }),
                   let slot = template.slot(id: panel.slotID),
                   visiblePanelIDs.contains(panel.id) {
                    let rect = panelRect(for: slot, canvasSize: size, gutter: gutter)
                    if LoreBookLayout.usesPageCallout(
                        characterCount: overlay.text.count,
                        panelWidth: rect.width
                    ) {
                        pageCallout(overlay, panel: panel, panelRect: rect, canvasSize: size)
                    }
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(LoreMangaAccessibility.narrative(
            for: page,
            visiblePanelIDs: visiblePanelIDs
        ))
    }

    private func panelView(
        _ panel: LorePanelDefinition,
        slot: LoreMangaPanelSlot,
        rect: CGRect
    ) -> some View {
        ZStack {
            panelArtwork(for: panel)
                .clipShape(LoreMangaPanelShape(points: slot.clipPolygon))
                .overlay(
                    LoreMangaPanelShape(points: slot.clipPolygon)
                        .stroke(Color.black, lineWidth: 2)
                )

            ForEach(attachedOverlays(for: panel, panelWidth: rect.width), id: \.id) { overlay in
                LoreMangaTextOverlay(overlay: overlay, compact: rect.width < 220)
                    .frame(maxWidth: max(40, min(280, rect.width - 12)))
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: alignment(for: overlay.placement)
                    )
                    .padding(6)
            }
        }
    }

    private func attachedOverlays(
        for panel: LorePanelDefinition,
        panelWidth: CGFloat
    ) -> [ResolvedLoreTextOverlay] {
        page.composition.textOverlays.filter {
            $0.panelID == panel.id && !LoreBookLayout.usesPageCallout(
                characterCount: $0.text.count,
                panelWidth: panelWidth
            )
        }
    }

    @ViewBuilder
    private func panelArtwork(for panel: LorePanelDefinition) -> some View {
        if panel.role == .motion, let first = motionFrames.first {
            if reduceMotion || !isBookOpen || scenePhase != .active || motionFrames.count == 1 {
                panelImage(first, focalPoint: panel.focalPoint)
            } else {
                TimelineView(.animation(
                    minimumInterval: Double(page.frameDurationMilliseconds) / 1_000
                )) { context in
                    let duration = Double(page.frameDurationMilliseconds) / 1_000
                    let index = Int(context.date.timeIntervalSinceReferenceDate / duration) % motionFrames.count
                    panelImage(motionFrames[index], focalPoint: panel.focalPoint)
                }
            }
        } else if panel.role == .motion, let anchor = contextCells.first {
            panelImage(anchor, focalPoint: panel.focalPoint)
        } else if let sourceCell = panel.sourceCell, contextCells.indices.contains(sourceCell) {
            panelImage(contextCells[sourceCell], focalPoint: panel.focalPoint)
        }
    }

    private func panelImage(_ image: CGImage, focalPoint: LoreFocalPoint) -> some View {
        GeometryReader { geometry in
            let sourceSize = CGSize(width: image.width, height: image.height)
            let scale = max(
                geometry.size.width / max(1, sourceSize.width),
                geometry.size.height / max(1, sourceSize.height)
            )
            let renderedSize = CGSize(
                width: sourceSize.width * scale,
                height: sourceSize.height * scale
            )
            let overflow = CGSize(
                width: max(0, renderedSize.width - geometry.size.width),
                height: max(0, renderedSize.height - geometry.size.height)
            )
            let focalX = min(1, max(0, focalPoint.x))
            let focalY = min(1, max(0, focalPoint.y))

            Image(decorative: image, scale: 1)
                .resizable()
                .frame(width: renderedSize.width, height: renderedSize.height)
                .position(
                    x: geometry.size.width / 2 + (0.5 - focalX) * overflow.width,
                    y: geometry.size.height / 2 + (0.5 - focalY) * overflow.height
                )
                .accessibilityHidden(true)
        }
    }

    private func pageCallout(
        _ overlay: ResolvedLoreTextOverlay,
        panel: LorePanelDefinition,
        panelRect: CGRect,
        canvasSize: CGSize
    ) -> some View {
        LoreMangaTextOverlay(overlay: overlay, compact: true)
            .frame(maxWidth: min(280, max(40, canvasSize.width - 12)))
            .background(Color(red: 0.98, green: 0.93, blue: 0.82))
            .frame(
                width: max(0, canvasSize.width - 12),
                height: max(0, canvasSize.height - 12),
                alignment: nearestPageEdgeAlignment(for: panelRect, canvasSize: canvasSize)
            )
            .position(x: canvasSize.width / 2, y: canvasSize.height / 2)
    }

    private func panelRect(
        for slot: LoreMangaPanelSlot,
        canvasSize: CGSize,
        gutter: CGFloat
    ) -> CGRect {
        CGRect(
            x: slot.frame.x * canvasSize.width,
            y: slot.frame.y * canvasSize.height,
            width: slot.frame.width * canvasSize.width,
            height: slot.frame.height * canvasSize.height
        ).insetBy(dx: gutter / 2, dy: gutter / 2)
    }

    private func alignment(for placement: LoreTextPlacement) -> Alignment {
        switch placement {
        case .topLeading: .topLeading
        case .topTrailing: .topTrailing
        case .bottomLeading: .bottomLeading
        case .bottomTrailing: .bottomTrailing
        case .center: .center
        }
    }

    private func nearestPageEdgeAlignment(for rect: CGRect, canvasSize: CGSize) -> Alignment {
        let candidates: [(distance: CGFloat, alignment: Alignment)] = [
            (rect.midX, rect.midY < canvasSize.height / 2 ? .topLeading : .bottomLeading),
            (canvasSize.width - rect.midX, rect.midY < canvasSize.height / 2 ? .topTrailing : .bottomTrailing),
            (rect.midY, rect.midX < canvasSize.width / 2 ? .topLeading : .topTrailing),
            (canvasSize.height - rect.midY, rect.midX < canvasSize.width / 2 ? .bottomLeading : .bottomTrailing)
        ]
        return candidates.min(by: { $0.distance < $1.distance })?.alignment ?? .topLeading
    }
}
