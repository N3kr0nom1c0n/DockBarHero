import Foundation

@MainActor
protocol SettingsControlling: AnyObject {
    var onSettings: ((AppSettings) -> Void)? { get set }
    func start()
    func update(_ settings: AppSettings)
    func stopAndSave() async
}

@MainActor
final class SettingsSession: SettingsControlling {
    var onSettings: ((AppSettings) -> Void)?

    private let store: any SettingsStoring
    private var latest = AppSettings.defaults
    private var pendingSave: AppSettings?
    private var loadTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var updateRevision = 0
    private var hasStarted = false

    init(store: any SettingsStoring) {
        self.store = store
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        let revisionAtStart = updateRevision
        loadTask = Task { @MainActor [weak self, store] in
            let loaded = await store.load()
            guard let self else { return }
            if self.updateRevision == revisionAtStart {
                self.latest = loaded
            }
            self.onSettings?(self.latest)
        }
    }

    func update(_ settings: AppSettings) {
        latest = settings
        updateRevision &+= 1
        pendingSave = settings
        startSaveLoopIfNeeded()
    }

    func stopAndSave() async {
        await loadTask?.value
        pendingSave = latest
        startSaveLoopIfNeeded()
        await saveTask?.value
        do {
            try await store.save(latest)
        } catch {
            AppLog.persistence.error("Final settings save failed")
        }
    }

    private func startSaveLoopIfNeeded() {
        guard saveTask == nil else { return }
        saveTask = Task { @MainActor [weak self, store] in
            guard let self else { return }
            while let settings = self.pendingSave {
                self.pendingSave = nil
                do {
                    try await store.save(settings)
                } catch {
                    AppLog.persistence.error("Settings save failed")
                }
            }
            self.saveTask = nil
            if self.pendingSave != nil {
                self.startSaveLoopIfNeeded()
            }
        }
    }
}
