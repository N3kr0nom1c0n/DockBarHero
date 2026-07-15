import Combine

@MainActor
protocol LoreReaderControlling: AnyObject {
    func update(settings: AppSettings, pages: [ResolvedLorePage])
    func open()
    func close()
    func applicationBecameActive()
    func applicationBecameInactive()
    func select(_ pageID: LorePageID)
    func replay()
    func skip()
    func previewVolume(detent: Int)
}

@MainActor
final class SilentLoreReaderController: LoreReaderControlling {
    func update(settings: AppSettings, pages: [ResolvedLorePage]) { }
    func open() { }
    func close() { }
    func applicationBecameActive() { }
    func applicationBecameInactive() { }
    func select(_ pageID: LorePageID) { }
    func replay() { }
    func skip() { }
    func previewVolume(detent: Int) { }
}

@MainActor
final class LoreReaderController: ObservableObject, LoreReaderControlling {
    @Published private(set) var isOpen = false
    @Published private(set) var currentPageID: LorePageID?
    @Published private(set) var reactionText = ""
    @Published private(set) var isSpeaking = false
    @Published private(set) var pages: [ResolvedLorePage] = []
    var onAutoReadPage: ((LorePageID) -> Void)?

    private let dialogue: SpokenDialogueCatalog
    private let speech: LoreSpeechControlling
    private var settings = AppSettings.defaults
    private var applicationIsActive = false
    private var cueIndex = 0
    private var giggleIndex = 0
    private let giggles = ["Heh.", "Hehehehe.", "Oh ho ho."]

    init(dialogue: SpokenDialogueCatalog, speech: LoreSpeechControlling) {
        self.dialogue = dialogue
        self.speech = speech
    }

    func update(settings: AppSettings, pages: [ResolvedLorePage]) {
        self.settings = settings
        self.pages = pages
        if currentPageID == nil || !pages.contains(where: { $0.id == currentPageID }) {
            currentPageID = pages.first?.id
            cueIndex = 0
        }
        if !settings.spokenDialogueEnabled {
            stopPlayback()
        }
    }

    func open() {
        isOpen = true
        reactionText = "The Book opens itself half an inch farther out of spite."
        autoReadCurrentPageIfNeeded()
    }

    func close() {
        guard isOpen else { return }
        isOpen = false
        reactionText = "Fine. I was done talking anyway."
        stopPlayback()
    }

    func applicationBecameActive() {
        applicationIsActive = true
        autoReadCurrentPageIfNeeded()
    }

    func applicationBecameInactive() {
        applicationIsActive = false
        stopPlayback()
    }

    func select(_ pageID: LorePageID) {
        guard pages.contains(where: { $0.id == pageID }) else {
            reactionText = "That page is locked because the plot hasn't suffered enough yet."
            return
        }
        speech.stop()
        isSpeaking = false
        currentPageID = pageID
        cueIndex = 0
        autoReadCurrentPageIfNeeded()
    }

    func replay() {
        cueIndex = 0
        playCurrentCue()
    }

    func skip() {
        guard let page = currentPage else { return }
        speech.stop()
        cueIndex += 1
        if cueIndex < page.dialogueCueIDs.count {
            playCurrentCue()
        } else {
            isSpeaking = false
            reactionText = "You skipped my best delivery. Objectively."
        }
    }

    func previewVolume(detent: Int) {
        let text = giggles[giggleIndex % giggles.count]
        giggleIndex += 1
        reactionText = text
        guard canSpeak else { return }
        speech.stopPreview()
        speech.previewGiggle(text, gain: BookVolumeMapping.gain(for: detent))
    }

    func arrowCorrected() {
        reactionText = settings.loreLanguageMode == .clean
            ? "Slander. The arrow has always pointed left. This is manga. You were reading it backward."
            : "Slander. The arrow has always pointed left. This is manga, you jackass. You were reading it backwards."
    }

    private var currentPage: ResolvedLorePage? {
        pages.first(where: { $0.id == currentPageID })
    }

    private var canSpeak: Bool {
        isOpen && applicationIsActive && settings.spokenDialogueEnabled
    }

    private func playCurrentCue() {
        guard canSpeak, let page = currentPage,
              page.dialogueCueIDs.indices.contains(cueIndex),
              let cue = dialogue.resolve(cueID: page.dialogueCueIDs[cueIndex], languageMode: settings.loreLanguageMode) else {
            isSpeaking = false
            return
        }
        speech.speak(cue, gain: settings.bookOutputGain)
        isSpeaking = true
    }

    private func autoReadCurrentPageIfNeeded() {
        guard settings.autoReadNewLorePages, canSpeak, let page = currentPage else { return }
        if page.id.rawValue == "prologue.level-100000", settings.hasSeenCurrentRunPrologue { return }
        if let lastID = settings.lastAutoReadLorePageID,
           let lastIndex = pages.firstIndex(where: { $0.id.rawValue == lastID }),
           let currentIndex = pages.firstIndex(where: { $0.id == page.id }),
           currentIndex <= lastIndex {
            return
        }
        cueIndex = 0
        playCurrentCue()
        settings.lastAutoReadLorePageID = page.id.rawValue
        if page.id.rawValue == "prologue.level-100000" {
            settings.hasSeenCurrentRunPrologue = true
        }
        onAutoReadPage?(page.id)
    }

    private func stopPlayback() {
        speech.stop()
        speech.stopPreview()
        isSpeaking = false
    }
}
