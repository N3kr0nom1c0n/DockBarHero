import AppKit
import CoreGraphics
import SpriteKit

enum SpriteToken: Hashable, Sendable {
    case hero
    case enemy
}

enum SpriteAction: Hashable, Sendable {
    case idle
    case attack
    case hit
    case defeated
}

@MainActor
protocol SpriteCatalog: AnyObject {
    func textures(for token: SpriteToken, action: SpriteAction) -> [SKTexture]
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
