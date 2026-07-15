enum LoreMangaAccessibility {
    static func narrative(for page: ResolvedLorePage) -> String {
        let panels = page.composition.panels.sorted { $0.readingOrder < $1.readingOrder }
        let overlayText = panels.flatMap { panel in
            page.composition.textOverlays.compactMap { overlay in
                overlay.panelID == panel.id && overlay.style != .soundEffect ? overlay.text : nil
            }
        }
        return ([page.accessibilityDescription] + overlayText).joined(separator: "\n")
    }
}
