import Foundation

struct LorePageID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String
}

struct LoreTextVariants: Codable, Equatable, Sendable {
    let unfiltered: String
    let clean: String
}

struct LoreArtVariants: Codable, Equatable, Sendable {
    let safeSpriteSheet: String
    let adultSpriteSheet: String?
    let accessibilitySafe: String
    let accessibilityAdult: String?
}

struct LorePageDefinition: Codable, Equatable, Sendable {
    let id: LorePageID
    let sortIndex: Int
    let title: LoreTextVariants
    let body: LoreTextVariants
    let unlockAfterVictoryLevel: Int?
    let art: LoreArtVariants
    let dialogueCueIDs: [String]
    let frameCount: Int
    let frameDurationMilliseconds: Int
}

struct LoreCatalog: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let pages: [LorePageDefinition]
}

struct ResolvedLorePage: Identifiable, Equatable, Sendable {
    let id: LorePageID
    let title: String
    let body: String
    let spriteSheetName: String
    let accessibilityDescription: String
    let dialogueCueIDs: [String]
    let frameCount: Int
    let frameDurationMilliseconds: Int
}
