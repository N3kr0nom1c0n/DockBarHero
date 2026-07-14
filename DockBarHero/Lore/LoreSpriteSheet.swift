import CoreGraphics
import Foundation
import ImageIO

enum LoreSpriteSheetError: Error, Equatable {
    case resourceMissing(String)
    case invalidDimensions
    case invalidFrameCount(Int)
    case imageDecodeFailed
    case cropFailed
}

enum LoreSpriteSheet {
    static func frameRects(pixelWidth: Int, pixelHeight: Int, frameCount: Int) throws -> [CGRect] {
        guard frameCount == 4 else { throw LoreSpriteSheetError.invalidFrameCount(frameCount) }
        guard pixelWidth == pixelHeight, pixelWidth.isMultiple(of: 2), pixelHeight.isMultiple(of: 2) else {
            throw LoreSpriteSheetError.invalidDimensions
        }
        let halfWidth = pixelWidth / 2
        let halfHeight = pixelHeight / 2
        return [
            CGRect(x: 0, y: halfHeight, width: halfWidth, height: halfHeight),
            CGRect(x: halfWidth, y: halfHeight, width: halfWidth, height: halfHeight),
            CGRect(x: 0, y: 0, width: halfWidth, height: halfHeight),
            CGRect(x: halfWidth, y: 0, width: halfWidth, height: halfHeight)
        ]
    }

    static func frames(named name: String, frameCount: Int = 4, bundle: Bundle = .main) throws -> [CGImage] {
        guard let url = bundle.url(forResource: name, withExtension: "png") else {
            throw LoreSpriteSheetError.resourceMissing(name)
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw LoreSpriteSheetError.imageDecodeFailed
        }
        return try frameRects(pixelWidth: image.width, pixelHeight: image.height, frameCount: frameCount).map { rect in
            guard let crop = image.cropping(to: rect) else { throw LoreSpriteSheetError.cropFailed }
            return crop
        }
    }
}
