import CoreGraphics
import Foundation
import ImageIO

enum LoreContextSheetError: Error, Equatable {
    case invalidDimensions
    case resourceMissing(String)
    case imageDecodeFailed
    case cropFailed
}

enum LoreContextSheet {
    static func cellRects(pixelWidth: Int, pixelHeight: Int) throws -> [CGRect] {
        guard pixelWidth.isMultiple(of: 3), pixelHeight.isMultiple(of: 2) else {
            throw LoreContextSheetError.invalidDimensions
        }
        let cellWidth = pixelWidth / 3
        let cellHeight = pixelHeight / 2
        guard cellWidth == cellHeight else { throw LoreContextSheetError.invalidDimensions }

        return [
            CGRect(x: cellWidth * 2, y: cellHeight, width: cellWidth, height: cellHeight),
            CGRect(x: cellWidth, y: cellHeight, width: cellWidth, height: cellHeight),
            CGRect(x: 0, y: cellHeight, width: cellWidth, height: cellHeight),
            CGRect(x: cellWidth * 2, y: 0, width: cellWidth, height: cellHeight),
            CGRect(x: cellWidth, y: 0, width: cellWidth, height: cellHeight),
            CGRect(x: 0, y: 0, width: cellWidth, height: cellHeight)
        ]
    }

    static func cells(named name: String, bundle: Bundle = .main) throws -> [CGImage] {
        guard let url = bundle.url(forResource: name, withExtension: "png") else {
            throw LoreContextSheetError.resourceMissing(name)
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw LoreContextSheetError.imageDecodeFailed
        }
        return try cellRects(pixelWidth: image.width, pixelHeight: image.height).map { rect in
            guard let crop = image.cropping(to: rect) else { throw LoreContextSheetError.cropFailed }
            return crop
        }
    }
}
