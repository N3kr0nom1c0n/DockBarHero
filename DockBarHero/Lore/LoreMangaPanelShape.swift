import SwiftUI

struct LoreMangaPanelShape: Shape {
    let points: [LoreNormalizedPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(
            x: rect.minX + first.x * rect.width,
            y: rect.minY + first.y * rect.height
        ))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(
                x: rect.minX + point.x * rect.width,
                y: rect.minY + point.y * rect.height
            ))
        }
        path.closeSubpath()
        return path
    }
}
