import AVFoundation

struct LoreAudioManifest: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let entries: [LoreAudioEntry]
}

struct LoreAudioEntry: Codable, Equatable, Sendable {
    let cueID: String
    let unfiltered: String
    let clean: String
}

enum LoreAudioManifestError: Error, Equatable {
    case resourceMissing
    case unsupportedSchema(Int)
    case duplicateCueID(String)
    case missingRequiredValue(String)
}

extension LoreAudioManifest {
    static func bundled(bundle: Bundle = .main) throws -> LoreAudioManifest {
        guard let url = bundle.url(forResource: "LoreAudioManifest", withExtension: "json") else {
            throw LoreAudioManifestError.resourceMissing
        }
        let decoded = try JSONDecoder().decode(LoreAudioManifest.self, from: Data(contentsOf: url))
        return try validated(decoded)
    }

    static func validated(_ manifest: LoreAudioManifest) throws -> LoreAudioManifest {
        guard manifest.schemaVersion == 1 else {
            throw LoreAudioManifestError.unsupportedSchema(manifest.schemaVersion)
        }
        var cueIDs = Set<String>()
        for entry in manifest.entries {
            guard cueIDs.insert(entry.cueID).inserted else {
                throw LoreAudioManifestError.duplicateCueID(entry.cueID)
            }
            guard !entry.cueID.isEmpty, !entry.unfiltered.isEmpty, !entry.clean.isEmpty else {
                throw LoreAudioManifestError.missingRequiredValue(entry.cueID)
            }
        }
        return manifest
    }

    func assetName(cueID: String, languageMode: LoreLanguageMode) -> String? {
        guard let entry = entries.first(where: { $0.cueID == cueID }) else { return nil }
        return languageMode == .clean ? entry.clean : entry.unfiltered
    }
}

@MainActor
protocol LoreSpeechControlling: AnyObject {
    func speak(_ cue: ResolvedDialogueCue, gain: Float)
    func stop()
    func stopPreview()
    func previewGiggle(_ text: String, gain: Float)
}

@MainActor
final class SystemLoreSpeechService: NSObject, LoreSpeechControlling {
    private let synthesizer = AVSpeechSynthesizer()
    private let previewSynthesizer = AVSpeechSynthesizer()

    func speak(_ cue: ResolvedDialogueCue, gain: Float) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: cue.text)
        utterance.rate = cue.speaker.rate
        utterance.pitchMultiplier = cue.speaker.pitch
        utterance.volume = gain
        synthesizer.speak(utterance)
    }

    func stop() { synthesizer.stopSpeaking(at: .immediate) }
    func stopPreview() { previewSynthesizer.stopSpeaking(at: .immediate) }

    func previewGiggle(_ text: String, gain: Float) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.42
        utterance.pitchMultiplier = 0.88
        utterance.volume = gain
        previewSynthesizer.speak(utterance)
    }
}
