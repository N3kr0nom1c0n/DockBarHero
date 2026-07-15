import Foundation

enum LoreLanguageMode: String, Codable, CaseIterable, Equatable, Sendable {
    case unfiltered
    case clean
}

enum LoreIllustrationMode: String, Codable, CaseIterable, Equatable, Sendable {
    case safe
    case adult
}

enum BookVolumeMapping {
    static func gain(for detent: Int) -> Float {
        Float(1.0 - 0.09 * Double(min(max(detent, 0), 10)))
    }

    static func accessibilityValue(for detent: Int) -> String {
        "\(Int((gain(for: detent) * 100).rounded())) percent, lower numbers are louder"
    }
}

struct AppSettings: Codable, Equatable, Sendable {
    static let currentVersion = 2

    let schemaVersion: Int
    var manualVisibility: ManualVisibility
    var animationMode: AnimationMode
    var inputMode: InputMode
    var loreLanguageMode: LoreLanguageMode
    var loreIllustrationMode: LoreIllustrationMode
    var spokenDialogueEnabled: Bool
    var bookVolumeDetent: Int
    var autoReadNewLorePages: Bool
    var hasSeenCurrentRunPrologue: Bool
    var lastAutoReadLorePageID: String?

    init(
        schemaVersion: Int,
        manualVisibility: ManualVisibility,
        animationMode: AnimationMode,
        inputMode: InputMode,
        loreLanguageMode: LoreLanguageMode = .unfiltered,
        loreIllustrationMode: LoreIllustrationMode = .safe,
        spokenDialogueEnabled: Bool = false,
        bookVolumeDetent: Int = 5,
        autoReadNewLorePages: Bool = true,
        hasSeenCurrentRunPrologue: Bool = false,
        lastAutoReadLorePageID: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.manualVisibility = manualVisibility
        self.animationMode = animationMode
        self.inputMode = inputMode
        self.loreLanguageMode = loreLanguageMode
        self.loreIllustrationMode = loreIllustrationMode
        self.spokenDialogueEnabled = spokenDialogueEnabled
        self.bookVolumeDetent = bookVolumeDetent
        self.autoReadNewLorePages = autoReadNewLorePages
        self.hasSeenCurrentRunPrologue = hasSeenCurrentRunPrologue
        self.lastAutoReadLorePageID = lastAutoReadLorePageID
    }

    var bookOutputGain: Float {
        BookVolumeMapping.gain(for: bookVolumeDetent)
    }

    static let defaults = AppSettings(
        schemaVersion: currentVersion,
        manualVisibility: .shown,
        animationMode: .running,
        inputMode: .passive
    )
}

enum SettingsDecodingError: Error, Equatable {
    case unsupportedVersion(Int)
    case invalidBookVolumeDetent(Int)
}

struct SettingsCodec: Sendable {
    private struct VersionHeader: Decodable {
        let schemaVersion: Int
    }

    func encode(_ settings: AppSettings) throws -> Data {
        guard settings.schemaVersion == AppSettings.currentVersion else {
            throw SettingsDecodingError.unsupportedVersion(settings.schemaVersion)
        }
        try validate(settings)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(settings)
    }

    func decode(_ data: Data) throws -> AppSettings {
        let header = try JSONDecoder().decode(VersionHeader.self, from: data)
        switch header.schemaVersion {
        case 1:
            let legacy = try JSONDecoder().decode(LegacyV1Settings.self, from: data)
            return AppSettings(
                schemaVersion: AppSettings.currentVersion,
                manualVisibility: legacy.manualVisibility,
                animationMode: legacy.animationMode,
                inputMode: legacy.inputMode
            )
        case AppSettings.currentVersion:
            let settings = try JSONDecoder().decode(AppSettings.self, from: data)
            try validate(settings)
            return settings
        default:
            throw SettingsDecodingError.unsupportedVersion(header.schemaVersion)
        }
    }

    private func validate(_ settings: AppSettings) throws {
        guard (0...10).contains(settings.bookVolumeDetent) else {
            throw SettingsDecodingError.invalidBookVolumeDetent(settings.bookVolumeDetent)
        }
    }

    private struct LegacyV1Settings: Decodable {
        let manualVisibility: ManualVisibility
        let animationMode: AnimationMode
        let inputMode: InputMode
    }
}
