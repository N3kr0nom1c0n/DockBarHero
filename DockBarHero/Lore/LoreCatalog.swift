import Foundation

enum LoreCatalogError: Error, Equatable {
    case resourceMissing
    case unsupportedSchema(Int)
    case duplicatePageID(String)
    case nonascendingSortIndex
    case missingRequiredValue(String)
    case invalidUnlock(String)
    case invalidAnimation(String)
    case invalidComposition(String)
}

extension LoreCatalog {
    static func bundled(bundle: Bundle = .main) throws -> LoreCatalog {
        guard let url = bundle.url(forResource: "LoreCatalog", withExtension: "json") else {
            throw LoreCatalogError.resourceMissing
        }
        let decoded = try JSONDecoder().decode(LoreCatalog.self, from: Data(contentsOf: url))
        return try validated(decoded)
    }

    static func validated(_ catalog: LoreCatalog) throws -> LoreCatalog {
        guard catalog.schemaVersion == 2 else {
            throw LoreCatalogError.unsupportedSchema(catalog.schemaVersion)
        }

        var ids = Set<String>()
        var previousIndex: Int?
        for page in catalog.pages {
            guard ids.insert(page.id.rawValue).inserted else {
                throw LoreCatalogError.duplicatePageID(page.id.rawValue)
            }
            if let previousIndex, page.sortIndex <= previousIndex {
                throw LoreCatalogError.nonascendingSortIndex
            }
            previousIndex = page.sortIndex

            let required = [
                page.id.rawValue, page.title.unfiltered, page.title.clean,
                page.body.unfiltered, page.body.clean, page.art.safeSpriteSheet,
                page.art.accessibilitySafe
            ]
            guard required.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                throw LoreCatalogError.missingRequiredValue(page.id.rawValue)
            }
            if let unlock = page.unlockAfterVictoryLevel, unlock < 1 {
                throw LoreCatalogError.invalidUnlock(page.id.rawValue)
            }
            guard page.frameCount == 4, page.frameDurationMilliseconds > 0 else {
                throw LoreCatalogError.invalidAnimation(page.id.rawValue)
            }
            if page.art.adultSpriteSheet != nil,
               page.art.accessibilityAdult?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                throw LoreCatalogError.missingRequiredValue(page.id.rawValue)
            }

            let panels = page.composition.panels
            let panelIDs = panels.map(\.id)
            let overlays = page.composition.textOverlays
            let template = LoreMangaLayout.template(for: page.composition.layoutID)
            guard panels.count == template.slots.count,
                  Set(panels.map(\.slotID)) == Set(template.slots.map(\.id)),
                  (5...7).contains(panels.count),
                  panels.filter({ $0.role == .motion }).count == 1,
                  Set(panelIDs).count == panelIDs.count,
                  Set(panels.map(\.slotID)).count == panels.count,
                  Set(panels.map(\.readingOrder)).count == panels.count,
                  !page.composition.safeContextSheet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  panels.allSatisfy({
                      (0...1).contains($0.focalPoint.x) &&
                      (0...1).contains($0.focalPoint.y) &&
                      ($0.role == .motion ? $0.sourceCell == nil : true) &&
                      ($0.role == .still ? $0.sourceCell.map { (0...5).contains($0) } == true : true)
                  }),
                  (page.composition.adultContextSheet.map {
                      !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  } ?? true),
                  Set(overlays.map(\.id)).count == overlays.count,
                  overlays.allSatisfy({
                      panelIDs.contains($0.panelID) &&
                      !$0.copy.unfiltered.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                      !$0.copy.clean.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  }),
                  Set(page.composition.textOverlays.compactMap(\.dialogueCueID)) == Set(page.dialogueCueIDs) else {
                throw LoreCatalogError.invalidComposition(page.id.rawValue)
            }
        }
        return catalog
    }
}
