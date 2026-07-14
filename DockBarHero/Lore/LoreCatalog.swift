import Foundation

enum LoreCatalogError: Error, Equatable {
    case resourceMissing
    case unsupportedSchema(Int)
    case duplicatePageID(String)
    case nonascendingSortIndex
    case missingRequiredValue(String)
    case invalidUnlock(String)
    case invalidAnimation(String)
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
        guard catalog.schemaVersion == 1 else {
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
        }
        return catalog
    }
}
