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

enum LoreMangaLayoutID: String, Codable, CaseIterable, Hashable, Sendable {
    case cascadeFive, brokenSix, staggeredSix, shatteredSeven
}

enum LorePanelRole: String, Codable, Equatable, Sendable {
    case motion, still, gag
}

enum LoreTextOverlayStyle: String, Codable, Equatable, Sendable {
    case title, narration, speech, soundEffect
}

enum LoreTextPlacement: String, Codable, Equatable, Sendable {
    case topLeading, topTrailing, bottomLeading, bottomTrailing, center
}

struct LoreFocalPoint: Codable, Equatable, Sendable {
    let x: Double
    let y: Double
}

struct LorePanelDefinition: Codable, Equatable, Sendable {
    let id: String
    let slotID: String
    let role: LorePanelRole
    let sourceCell: Int?
    let readingOrder: Int
    let focalPoint: LoreFocalPoint
}

struct LoreTextOverlayDefinition: Codable, Equatable, Sendable {
    let id: String
    let panelID: String
    let style: LoreTextOverlayStyle
    let placement: LoreTextPlacement
    let speakerID: String?
    let dialogueCueID: String?
    let copy: LoreTextVariants
}

struct LoreCompositionDefinition: Codable, Equatable, Sendable {
    let layoutID: LoreMangaLayoutID
    let safeContextSheet: String
    let adultContextSheet: String?
    let panels: [LorePanelDefinition]
    let textOverlays: [LoreTextOverlayDefinition]
}

struct LorePageDefinition: Codable, Equatable, Sendable {
    let id: LorePageID
    let sortIndex: Int
    let title: LoreTextVariants
    let body: LoreTextVariants
    let unlockAfterVictoryLevel: Int?
    let art: LoreArtVariants
    let composition: LoreCompositionDefinition
    let dialogueCueIDs: [String]
    let frameCount: Int
    let frameDurationMilliseconds: Int
}

struct ResolvedLoreTextOverlay: Equatable, Sendable {
    let id: String
    let panelID: String
    let style: LoreTextOverlayStyle
    let placement: LoreTextPlacement
    let speakerID: String?
    let dialogueCueID: String?
    let text: String
}

struct ResolvedLoreComposition: Equatable, Sendable {
    let layoutID: LoreMangaLayoutID
    let contextSheetName: String
    let panels: [LorePanelDefinition]
    let textOverlays: [ResolvedLoreTextOverlay]
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
    let composition: ResolvedLoreComposition
    let dialogueCueIDs: [String]
    let frameCount: Int
    let frameDurationMilliseconds: Int
}
