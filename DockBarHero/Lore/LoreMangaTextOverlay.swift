import SwiftUI

struct LoreMangaTextOverlay: View {
    let overlay: ResolvedLoreTextOverlay
    let compact: Bool

    @ViewBuilder
    var body: some View {
        switch overlay.style {
        case .title, .narration:
            Text(overlay.text)
                .font(.system(
                    size: overlay.style == .title ? (compact ? 14 : 16) : (compact ? 13 : 14),
                    weight: .black,
                    design: .serif
                ))
                .foregroundStyle(Color.black)
                .padding(compact ? 6 : 8)
                .background(Color(red: 0.98, green: 0.93, blue: 0.82).opacity(0.97))
                .overlay(Rectangle().stroke(Color.black, lineWidth: 1.5))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(overlay.text)
        case .speech:
            Text(overlay.text)
                .font(.system(size: compact ? 13 : 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.black)
                .padding(.horizontal, compact ? 8 : 10)
                .padding(.vertical, compact ? 7 : 9)
                .padding(.bottom, 5)
                .background(LoreSpeechBalloonShape().fill(Color.white.opacity(0.97)))
                .overlay(LoreSpeechBalloonShape().stroke(Color.black, lineWidth: 1.5))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(overlay.text)
        case .soundEffect:
            Text(overlay.text)
                .font(.system(size: compact ? 18 : 24, weight: .black, design: .rounded))
                .foregroundStyle(Color.white)
                .shadow(color: .black, radius: 0, x: 2, y: 0)
                .shadow(color: .black, radius: 0, x: -2, y: 0)
                .shadow(color: .black, radius: 0, x: 0, y: 2)
                .shadow(color: .black, radius: 0, x: 0, y: -2)
                .rotationEffect(.degrees(-8))
                .accessibilityHidden(true)
        }
    }
}

private struct LoreSpeechBalloonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let body = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: max(0, rect.height - 8)
        )
        var path = Path(roundedRect: body, cornerRadius: min(18, body.height / 2))
        path.move(to: CGPoint(x: body.minX + body.width * 0.72, y: body.maxY - 1))
        path.addLine(to: CGPoint(x: body.minX + body.width * 0.86, y: rect.maxY))
        path.addLine(to: CGPoint(x: body.minX + body.width * 0.62, y: body.maxY - 1))
        path.closeSubpath()
        return path
    }
}
