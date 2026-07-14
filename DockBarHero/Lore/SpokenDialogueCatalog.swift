import Foundation

struct DialogueSpeaker: Codable, Equatable, Sendable {
    let id: String
    let displayName: String
    let rate: Float
    let pitch: Float
    let preferredVoiceTraits: [String]
}

struct DialogueCue: Codable, Equatable, Sendable {
    let id: String
    let speakerID: String
    let unfiltered: String
    let clean: String
    let delivery: String
    let autoReadEligible: Bool
}

struct ResolvedDialogueCue: Equatable, Sendable {
    let id: String
    let speaker: DialogueSpeaker
    let text: String
    let delivery: String
}

struct SpokenDialogueCatalog: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let speakers: [DialogueSpeaker]
    let cues: [DialogueCue]
}

enum SpokenDialogueCatalogError: Error, Equatable {
    case resourceMissing
    case unsupportedSchema(Int)
    case duplicateSpeakerID(String)
    case duplicateCueID(String)
    case missingRequiredValue(String)
    case unknownSpeaker(String)
    case unknownLoreCue(String)
}

extension SpokenDialogueCatalog {
    static func bundled(bundle: Bundle = .main, loreCatalog: LoreCatalog? = nil) throws -> SpokenDialogueCatalog {
        guard let url = bundle.url(forResource: "SpokenDialogue", withExtension: "json") else {
            throw SpokenDialogueCatalogError.resourceMissing
        }
        let decoded = try JSONDecoder().decode(SpokenDialogueCatalog.self, from: Data(contentsOf: url))
        return try validated(decoded, loreCatalog: loreCatalog)
    }

    static func validated(_ catalog: SpokenDialogueCatalog, loreCatalog: LoreCatalog? = nil) throws -> SpokenDialogueCatalog {
        guard catalog.schemaVersion == 1 else {
            throw SpokenDialogueCatalogError.unsupportedSchema(catalog.schemaVersion)
        }
        var speakerIDs = Set<String>()
        for speaker in catalog.speakers {
            guard speakerIDs.insert(speaker.id).inserted else {
                throw SpokenDialogueCatalogError.duplicateSpeakerID(speaker.id)
            }
            guard !speaker.id.isEmpty, !speaker.displayName.isEmpty else {
                throw SpokenDialogueCatalogError.missingRequiredValue(speaker.id)
            }
        }

        var cueIDs = Set<String>()
        for cue in catalog.cues {
            guard cueIDs.insert(cue.id).inserted else {
                throw SpokenDialogueCatalogError.duplicateCueID(cue.id)
            }
            guard !cue.id.isEmpty, !cue.unfiltered.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !cue.clean.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !cue.delivery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SpokenDialogueCatalogError.missingRequiredValue(cue.id)
            }
            guard speakerIDs.contains(cue.speakerID) else {
                throw SpokenDialogueCatalogError.unknownSpeaker(cue.speakerID)
            }
        }

        if let loreCatalog {
            for cueID in loreCatalog.pages.flatMap(\.dialogueCueIDs) where !cueIDs.contains(cueID) {
                throw SpokenDialogueCatalogError.unknownLoreCue(cueID)
            }
        }
        return catalog
    }

    func resolve(cueID: String, languageMode: LoreLanguageMode) -> ResolvedDialogueCue? {
        guard let cue = cues.first(where: { $0.id == cueID }),
              let speaker = speakers.first(where: { $0.id == cue.speakerID }) else { return nil }
        return ResolvedDialogueCue(
            id: cue.id, speaker: speaker,
            text: languageMode == .clean ? cue.clean : cue.unfiltered,
            delivery: cue.delivery
        )
    }
}
