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
    case missingCueID(String)
    case unexpectedCueID(String)
    case cleanVariantRequiresDistinctAsset(String)
    case audioResourceUnreadable(String)
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

    func validateAudioResources(in bundle: Bundle) throws {
        let assetNames = Set(entries.flatMap { [$0.unfiltered, $0.clean] })
        for assetName in assetNames {
            let name = (assetName as NSString).deletingPathExtension
            let ext = (assetName as NSString).pathExtension
            guard let url = bundle.url(forResource: name, withExtension: ext) else {
                throw LoreAudioManifestError.audioResourceUnreadable(assetName)
            }
            do {
                _ = try AVAudioPlayer(contentsOf: url)
            } catch {
                throw LoreAudioManifestError.audioResourceUnreadable(assetName)
            }
        }
    }

    func validateCoverage(for dialogue: SpokenDialogueCatalog) throws {
        let expectedCueIDs = Set(dialogue.cues.map(\.id))
        let manifestCueIDs = Set(entries.map(\.cueID))
        for cueID in expectedCueIDs.subtracting(manifestCueIDs).sorted() {
            throw LoreAudioManifestError.missingCueID(cueID)
        }
        for cueID in manifestCueIDs.subtracting(expectedCueIDs).sorted() {
            throw LoreAudioManifestError.unexpectedCueID(cueID)
        }
        let entriesByCueID = Dictionary(uniqueKeysWithValues: entries.map { ($0.cueID, $0) })
        for cue in dialogue.cues where cue.clean != cue.unfiltered {
            guard let entry = entriesByCueID[cue.id], entry.clean != entry.unfiltered else {
                throw LoreAudioManifestError.cleanVariantRequiresDistinctAsset(cue.id)
            }
        }
    }
}

@MainActor
protocol LoreSpeechControlling: AnyObject {
    func speak(_ cue: ResolvedDialogueCue, gain: Float, completion: @escaping () -> Void)
    func stop()
    func stopPreview()
    func previewGiggle(_ text: String, gain: Float)
}

@MainActor
protocol LoreAudioPlaying: AnyObject {
    func play(resourceName: String, gain: Float, completion: @escaping () -> Void)
    func stop()
}

@MainActor
final class AVFoundationLoreAudioPlayer: NSObject, LoreAudioPlaying, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var activePlayback: (playerID: ObjectIdentifier, completion: () -> Void)?
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func play(resourceName: String, gain: Float, completion: @escaping () -> Void) {
        stop()
        let name = (resourceName as NSString).deletingPathExtension
        let ext = (resourceName as NSString).pathExtension
        guard let url = bundle.url(forResource: name, withExtension: ext) else {
            completion()
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = gain
            player.delegate = self
            player.prepareToPlay()
            self.player = player
            activePlayback = (ObjectIdentifier(player), completion)
            if !player.play() {
                completePlayback(playerID: ObjectIdentifier(player))
            }
        } catch {
            self.player = nil
            completion()
        }
    }

    func stop() {
        activePlayback = nil
        player?.stop()
        player = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let playerID = ObjectIdentifier(player)
        Task { @MainActor [weak self] in
            self?.completePlayback(playerID: playerID)
        }
    }

    private func completePlayback(playerID: ObjectIdentifier) {
        guard let activePlayback, activePlayback.playerID == playerID else { return }
        self.activePlayback = nil
        player = nil
        activePlayback.completion()
    }
}

@MainActor
final class RecordedLoreSpeechService: LoreSpeechControlling {
    private let manifest: LoreAudioManifest
    private let player: LoreAudioPlaying
    private let previewPlayer: LoreAudioPlaying

    init(manifest: LoreAudioManifest, player: LoreAudioPlaying, previewPlayer: LoreAudioPlaying) {
        self.manifest = manifest
        self.player = player
        self.previewPlayer = previewPlayer
    }

    convenience init(bundle: Bundle = .main, dialogue: SpokenDialogueCatalog) throws {
        let manifest = try LoreAudioManifest.bundled(bundle: bundle)
        try manifest.validateCoverage(for: dialogue)
        try manifest.validateAudioResources(in: bundle)
        self.init(
            manifest: manifest,
            player: AVFoundationLoreAudioPlayer(bundle: bundle),
            previewPlayer: AVFoundationLoreAudioPlayer(bundle: bundle)
        )
    }

    func speak(_ cue: ResolvedDialogueCue, gain: Float, completion: @escaping () -> Void) {
        guard let assetName = manifest.assetName(cueID: cue.id, languageMode: cue.languageMode) else {
            completion()
            return
        }
        player.play(resourceName: assetName, gain: gain, completion: completion)
    }

    func stop() { player.stop() }
    func stopPreview() { previewPlayer.stop() }

    func previewGiggle(_ text: String, gain: Float) {
        let cueID: String
        switch text {
        case "Hehehehe.": cueID = "interaction.volume.giggle-02"
        case "Oh ho ho.": cueID = "interaction.volume.giggle-03"
        default: cueID = "interaction.volume.giggle-01"
        }
        guard let assetName = manifest.assetName(cueID: cueID, languageMode: .unfiltered) else { return }
        previewPlayer.play(resourceName: assetName, gain: gain) { }
    }
}

@MainActor
final class SystemLoreSpeechService: NSObject, LoreSpeechControlling, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private let previewSynthesizer = AVSpeechSynthesizer()
    private var activeSpeech: (utteranceID: ObjectIdentifier, completion: () -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ cue: ResolvedDialogueCue, gain: Float, completion: @escaping () -> Void) {
        activeSpeech = nil
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: cue.text)
        utterance.rate = cue.speaker.rate
        utterance.pitchMultiplier = cue.speaker.pitch
        utterance.volume = gain
        activeSpeech = (ObjectIdentifier(utterance), completion)
        synthesizer.speak(utterance)
    }

    func stop() {
        activeSpeech = nil
        synthesizer.stopSpeaking(at: .immediate)
    }
    func stopPreview() { previewSynthesizer.stopSpeaking(at: .immediate) }

    func previewGiggle(_ text: String, gain: Float) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.42
        utterance.pitchMultiplier = 0.88
        utterance.volume = gain
        previewSynthesizer.speak(utterance)
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            self?.completeSpeech(utteranceID: utteranceID)
        }
    }

    private func completeSpeech(utteranceID: ObjectIdentifier) {
        guard let activeSpeech, activeSpeech.utteranceID == utteranceID else { return }
        self.activeSpeech = nil
        activeSpeech.completion()
    }
}
