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
    static let currentVersion = 3

    let schemaVersion: Int
    var manualVisibility: ManualVisibility
    var animationMode: AnimationMode
    var inputMode: InputMode
    var actorScalePercent: Int
    var railTextScalePercent: Int
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
        actorScalePercent: Int = 100,
        railTextScalePercent: Int = 100,
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
        self.actorScalePercent = actorScalePercent
        self.railTextScalePercent = railTextScalePercent
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
    case invalidActorScalePercent(Int)
    case invalidRailTextScalePercent(Int)
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
            let settings = AppSettings(
                schemaVersion: AppSettings.currentVersion,
                manualVisibility: legacy.manualVisibility,
                animationMode: legacy.animationMode,
                inputMode: legacy.inputMode
            )
            try validate(settings)
            return settings
        case 2:
            let legacy = try JSONDecoder().decode(LegacyV2Settings.self, from: data)
            let settings = AppSettings(
                schemaVersion: AppSettings.currentVersion,
                manualVisibility: legacy.manualVisibility,
                animationMode: legacy.animationMode,
                inputMode: legacy.inputMode,
                loreLanguageMode: legacy.loreLanguageMode,
                loreIllustrationMode: legacy.loreIllustrationMode,
                spokenDialogueEnabled: legacy.spokenDialogueEnabled,
                bookVolumeDetent: legacy.bookVolumeDetent,
                autoReadNewLorePages: legacy.autoReadNewLorePages,
                hasSeenCurrentRunPrologue: legacy.hasSeenCurrentRunPrologue,
                lastAutoReadLorePageID: legacy.lastAutoReadLorePageID
            )
            try validate(settings)
            return settings
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
        guard (75...140).contains(settings.actorScalePercent) else {
            throw SettingsDecodingError.invalidActorScalePercent(settings.actorScalePercent)
        }
        guard (85...130).contains(settings.railTextScalePercent) else {
            throw SettingsDecodingError.invalidRailTextScalePercent(settings.railTextScalePercent)
        }
    }

    private struct LegacyV1Settings: Decodable {
        let manualVisibility: ManualVisibility
        let animationMode: AnimationMode
        let inputMode: InputMode
    }

    private struct LegacyV2Settings: Decodable {
        let manualVisibility: ManualVisibility
        let animationMode: AnimationMode
        let inputMode: InputMode
        let loreLanguageMode: LoreLanguageMode
        let loreIllustrationMode: LoreIllustrationMode
        let spokenDialogueEnabled: Bool
        let bookVolumeDetent: Int
        let autoReadNewLorePages: Bool
        let hasSeenCurrentRunPrologue: Bool
        let lastAutoReadLorePageID: String?
    }
}
