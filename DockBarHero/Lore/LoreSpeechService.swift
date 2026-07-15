import AVFoundation

@MainActor
protocol LoreSpeechControlling: AnyObject {
    func speak(_ cue: ResolvedDialogueCue, gain: Float, completion: @escaping () -> Void)
    func stop()
    func stopPreview()
    func previewGiggle(_ text: String, gain: Float)
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
