import Foundation

struct AppSettings: Codable, Equatable, Sendable {
    static let currentVersion = 1

    let schemaVersion: Int
    var manualVisibility: ManualVisibility
    var animationMode: AnimationMode
    var inputMode: InputMode

    static let defaults = AppSettings(
        schemaVersion: currentVersion,
        manualVisibility: .shown,
        animationMode: .running,
        inputMode: .passive
    )
}

enum SettingsDecodingError: Error, Equatable {
    case unsupportedVersion(Int)
}

struct SettingsCodec: Sendable {
    private struct VersionHeader: Decodable {
        let schemaVersion: Int
    }

    func encode(_ settings: AppSettings) throws -> Data {
        guard settings.schemaVersion == AppSettings.currentVersion else {
            throw SettingsDecodingError.unsupportedVersion(settings.schemaVersion)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(settings)
    }

    func decode(_ data: Data) throws -> AppSettings {
        let header = try JSONDecoder().decode(VersionHeader.self, from: data)
        guard header.schemaVersion == AppSettings.currentVersion else {
            throw SettingsDecodingError.unsupportedVersion(header.schemaVersion)
        }
        return try JSONDecoder().decode(AppSettings.self, from: data)
    }
}
