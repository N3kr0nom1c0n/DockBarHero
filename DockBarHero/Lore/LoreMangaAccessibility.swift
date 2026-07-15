enum LoreMangaAccessibility {
    static func narrative(
        for page: ResolvedLorePage,
        visiblePanelIDs: Set<String>
    ) -> String {
        let panels = page.composition.panels
            .filter { visiblePanelIDs.contains($0.id) }
            .sorted { $0.readingOrder < $1.readingOrder }
        let overlayText = panels.flatMap { panel in
            page.composition.textOverlays.compactMap { overlay in
                overlay.panelID == panel.id && overlay.style != .soundEffect ? overlay.text : nil
            }
        }
        return ([page.accessibilityDescription] + overlayText).joined(separator: "\n")
    }
}
