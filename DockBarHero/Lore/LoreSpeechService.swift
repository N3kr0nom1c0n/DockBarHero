import AVFoundation

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
