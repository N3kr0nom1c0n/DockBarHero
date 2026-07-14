import AppKit
import CoreGraphics
import SpriteKit

enum SpriteToken: String, Codable, Hashable, Sendable {
    case hero, tank, dps, healer, enemy
    case goblin, skeleton, bandit, wolf, orc, bat, slime, harpy, mimic, ghost
    case darkMage, zombie, plantMonster
    case elementalSlimeNormal, elementalSlimeFire, elementalSlimeIce
    case elementalSlimeElectric, elementalSlimePoison, elementalSlimeEarth
    case eliteKnight, dreadSkeleton, infernalBrute, frostWraith
    case poisonNaga, stormLich, dragonWhelp, ancientGolem
    case ironrootWarchief, ossuarySovereign, embermawColossus, astralWyrm
}

enum SpriteAction: String, Codable, Hashable, Sendable {
    case idle, walk, run, jump, fall, land
    case attack, attack2, attack3, classAction
    case groupHeal, revive, blessing, block, defend, dodge
    case hit, defeated, victory
}

@MainActor
protocol SpriteCatalog: AnyObject {
    func textures(for token: SpriteToken, action: SpriteAction) -> [SKTexture]
    func clip(for token: SpriteToken, action: SpriteAction) -> SpriteClip
}

extension SpriteCatalog {
    func clip(for token: SpriteToken, action: SpriteAction) -> SpriteClip {
        SpriteClip(
            textures: textures(for: token, action: action),
            secondsPerFrame: 0.08,
            repeats: action == .idle
        )
    }
}

enum BundledSpriteCatalogError: Error {
    case unsupportedManifest
}

@MainActor
final class BundledSpriteCatalog: SpriteCatalog {
    typealias ImageProvider = (String) -> CGImage?

    private struct Manifest: Decodable {
        struct Cell: Decodable { let width: Int; let height: Int }
        struct Entry: Decodable {
            let token: SpriteToken
            let action: SpriteAction
            let resource: String
            let frameCount: Int
            let secondsPerFrame: TimeInterval
            let repeats: Bool
        }
        let version: Int
        let cell: Cell
        let clips: [Entry]
    }

    private struct Key: Hashable {
        let token: SpriteToken
        let action: SpriteAction
    }

    private let cell: CGSize
    private let entries: [Key: Manifest.Entry]
    private let imageProvider: ImageProvider
    private let fallback: any SpriteCatalog
    private var cachedClips: [Key: SpriteClip] = [:]
    private var loggedInvalidClips: Set<Key> = []

    init(
        manifestData: Data,
        imageProvider: @escaping ImageProvider,
        fallback: any SpriteCatalog
    ) throws {
        let manifest = try JSONDecoder().decode(Manifest.self, from: manifestData)
        guard manifest.version == 1,
              manifest.cell.width > 0,
              manifest.cell.height > 0 else {
            throw BundledSpriteCatalogError.unsupportedManifest
        }
        cell = CGSize(width: manifest.cell.width, height: manifest.cell.height)
        entries = Dictionary(
            manifest.clips.map { (Key(token: $0.token, action: $0.action), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        self.imageProvider = imageProvider
        self.fallback = fallback
    }

    convenience init?(bundle: Bundle = .main, fallback: any SpriteCatalog) {
        guard let manifestURL = Self.manifestURL(in: bundle),
              let data = try? Data(contentsOf: manifestURL) else { return nil }
        let root = manifestURL.deletingLastPathComponent()
        try? self.init(
            manifestData: data,
            imageProvider: { resource in
                let url = root.appendingPathComponent(resource)
                guard let image = NSImage(contentsOf: url) else { return nil }
                return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
            },
            fallback: fallback
        )
    }

    func textures(for token: SpriteToken, action: SpriteAction) -> [SKTexture] {
        clip(for: token, action: action).textures
    }

    func clip(for token: SpriteToken, action: SpriteAction) -> SpriteClip {
        let key = Key(token: token, action: action)
        if let cached = cachedClips[key] { return cached }
        guard let entry = entries[key],
              let clip = makeClip(entry) else {
            logInvalidOnce(key)
            return fallback.clip(for: token, action: action)
        }
        cachedClips[key] = clip
        return clip
    }

    static func productionCatalog(bundle: Bundle = .main) -> any SpriteCatalog {
        let fallback = BuiltinSpriteCatalog()
        return BundledSpriteCatalog(bundle: bundle, fallback: fallback) ?? fallback
    }

    private func makeClip(_ entry: Manifest.Entry) -> SpriteClip? {
        guard entry.frameCount > 0,
              entry.secondsPerFrame > 0,
              let image = imageProvider(entry.resource),
              image.width == Int(cell.width) * entry.frameCount,
              image.height == Int(cell.height) else { return nil }
        let textures = (0..<entry.frameCount).compactMap { frame -> SKTexture? in
            let rect = CGRect(
                x: frame * Int(cell.width),
                y: 0,
                width: Int(cell.width),
                height: Int(cell.height)
            )
            guard let frameImage = image.cropping(to: rect) else { return nil }
            let texture = SKTexture(cgImage: frameImage)
            texture.filteringMode = .nearest
            return texture
        }
        guard textures.count == entry.frameCount else { return nil }
        return SpriteClip(
            textures: textures,
            secondsPerFrame: entry.secondsPerFrame,
            repeats: entry.repeats
        )
    }

    private func logInvalidOnce(_ key: Key) {
        guard loggedInvalidClips.insert(key).inserted else { return }
        AppLog.scene.error(
            "Invalid or missing bundled sprite \(key.token.rawValue, privacy: .public)/\(key.action.rawValue, privacy: .public)"
        )
    }

    private static func manifestURL(in bundle: Bundle) -> URL? {
        [
            bundle.url(forResource: "manifest", withExtension: "json", subdirectory: "Sprites"),
            bundle.url(forResource: "manifest", withExtension: "json", subdirectory: "Resources/Sprites"),
            bundle.resourceURL?.appendingPathComponent("Sprites/manifest.json"),
            bundle.resourceURL?.appendingPathComponent("Resources/Sprites/manifest.json"),
        ].compactMap { $0 }.first(where: { FileManager.default.fileExists(atPath: $0.path) })
    }
}

@MainActor
final class BuiltinSpriteCatalog: SpriteCatalog {
    private let definitions: [SpriteToken: [SpriteAction: [PixelSpriteDefinition]]]
    private var loggedInvalidDefinitions: Set<String> = []

    init(
        definitions: [SpriteToken: [SpriteAction: [PixelSpriteDefinition]]] = BuiltinPixelSprites.definitions
    ) {
        self.definitions = definitions
    }

    func textures(for token: SpriteToken, action: SpriteAction) -> [SKTexture] {
        pixelDefinitions(for: token, action: action).map { definition in
            do {
                return try texture(for: definition)
            } catch {
                logInvalidOnce(token: token, action: action)
                return fallbackTexture()
            }
        }
    }

    func pixelData(for token: SpriteToken, action: SpriteAction) -> [[UInt32]] {
        pixelDefinitions(for: token, action: action).map { definition in
            do {
                return try definition.rgbaPixels()
            } catch {
                logInvalidOnce(token: token, action: action)
                return (try? Self.fallback.rgbaPixels()) ?? [0xFF00FFFF]
            }
        }
    }

    private func pixelDefinitions(
        for token: SpriteToken,
        action: SpriteAction
    ) -> [PixelSpriteDefinition] {
        definitions[token]?[action]
            ?? definitions[token]?[.idle]
            ?? [Self.fallback]
    }

    private func texture(for definition: PixelSpriteDefinition) throws -> SKTexture {
        let bytes = try definition.rgbaBytes()
        let data = Data(bytes) as CFData
        guard let provider = CGDataProvider(data: data),
              let image = CGImage(
                width: definition.width,
                height: definition.height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: definition.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
                    .union(.byteOrder32Big),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            throw PixelSpriteError.invalidDimensions
        }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        return texture
    }

    private func logInvalidOnce(token: SpriteToken, action: SpriteAction) {
        let key = "\(token)-\(action)"
        guard loggedInvalidDefinitions.insert(key).inserted else { return }
        AppLog.scene.error("Invalid sprite definition for \(key, privacy: .public)")
    }

    private func fallbackTexture() -> SKTexture {
        if let texture = try? texture(for: Self.fallback) {
            return texture
        }

        let image = NSImage(size: CGSize(width: 4, height: 4))
        image.lockFocus()
        NSColor.magenta.setFill()
        NSBezierPath(rect: CGRect(x: 0, y: 0, width: 4, height: 4)).fill()
        image.unlockFocus()
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }

    private static let fallback = PixelSpriteDefinition(
        width: 4,
        height: 4,
        palette: ["M": 0xFF00FFFF, "K": 0x000000FF],
        rows: ["MKMK", "KMKM", "MKMK", "KMKM"]
    )
}
