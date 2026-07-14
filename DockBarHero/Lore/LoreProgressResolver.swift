enum LoreProgressResolver {
    static func resolve(
        catalog: LoreCatalog,
        highestUnlockedLevel: Int,
        languageMode: LoreLanguageMode,
        illustrationMode: LoreIllustrationMode
    ) -> [ResolvedLorePage] {
        catalog.pages.compactMap { page in
            guard page.unlockAfterVictoryLevel.map({ highestUnlockedLevel > $0 }) ?? true else {
                return nil
            }

            let useAdult = illustrationMode == .adult && page.art.adultSpriteSheet != nil
            let contextSheetName = illustrationMode == .adult
                ? page.composition.adultContextSheet ?? page.composition.safeContextSheet
                : page.composition.safeContextSheet
            let overlays = page.composition.textOverlays.map {
                ResolvedLoreTextOverlay(
                    id: $0.id, panelID: $0.panelID, style: $0.style,
                    placement: $0.placement, speakerID: $0.speakerID,
                    dialogueCueID: $0.dialogueCueID,
                    text: languageMode == .clean ? $0.copy.clean : $0.copy.unfiltered
                )
            }
            return ResolvedLorePage(
                id: page.id,
                title: languageMode == .clean ? page.title.clean : page.title.unfiltered,
                body: languageMode == .clean ? page.body.clean : page.body.unfiltered,
                spriteSheetName: useAdult ? page.art.adultSpriteSheet! : page.art.safeSpriteSheet,
                accessibilityDescription: useAdult ? page.art.accessibilityAdult! : page.art.accessibilitySafe,
                composition: ResolvedLoreComposition(
                    layoutID: page.composition.layoutID,
                    contextSheetName: contextSheetName,
                    panels: page.composition.panels,
                    textOverlays: overlays
                ),
                dialogueCueIDs: page.dialogueCueIDs,
                frameCount: page.frameCount,
                frameDurationMilliseconds: page.frameDurationMilliseconds
            )
        }
    }
}
