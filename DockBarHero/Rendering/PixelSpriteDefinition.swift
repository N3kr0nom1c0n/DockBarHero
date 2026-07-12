import Foundation

enum PixelSpriteError: Error, Equatable {
    case invalidDimensions
    case invalidRowCount
    case invalidRowWidth(Int)
    case unknownPaletteCharacter(Character)
}

struct PixelSpriteDefinition: Equatable, Sendable {
    let width: Int
    let height: Int
    let palette: [Character: UInt32]
    let rows: [String]

    func rgbaPixels() throws -> [UInt32] {
        guard width > 0, height > 0 else { throw PixelSpriteError.invalidDimensions }
        guard rows.count == height else { throw PixelSpriteError.invalidRowCount }

        var pixels: [UInt32] = []
        pixels.reserveCapacity(width * height)
        for (index, row) in rows.enumerated() {
            guard row.count == width else { throw PixelSpriteError.invalidRowWidth(index) }
            for character in row {
                if character == "." {
                    pixels.append(0)
                } else if let color = palette[character] {
                    pixels.append(color)
                } else {
                    throw PixelSpriteError.unknownPaletteCharacter(character)
                }
            }
        }
        return pixels
    }

    func rgbaBytes() throws -> [UInt8] {
        try rgbaPixels().flatMap { color in
            [
                UInt8((color >> 24) & 0xFF),
                UInt8((color >> 16) & 0xFF),
                UInt8((color >> 8) & 0xFF),
                UInt8(color & 0xFF),
            ]
        }
    }
}
