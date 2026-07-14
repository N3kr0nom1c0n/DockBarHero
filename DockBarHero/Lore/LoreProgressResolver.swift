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
            return ResolvedLorePage(
                id: page.id,
                title: languageMode == .clean ? page.title.clean : page.title.unfiltered,
                body: languageMode == .clean ? page.body.clean : page.body.unfiltered,
                spriteSheetName: useAdult ? page.art.adultSpriteSheet! : page.art.safeSpriteSheet,
                accessibilityDescription: useAdult ? page.art.accessibilityAdult! : page.art.accessibilitySafe,
                dialogueCueIDs: page.dialogueCueIDs,
                frameCount: page.frameCount,
                frameDurationMilliseconds: page.frameDurationMilliseconds
            )
        }
    }
}
