import SwiftUI

private struct GlassSurface: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?
    let interactive: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(tint ?? WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else if #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(tint ?? .clear).interactive(interactive), in: .rect(cornerRadius: cornerRadius))
        } else {
            if let tint {
                content.background(tint, in: RoundedRectangle(cornerRadius: cornerRadius))
            } else {
                content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            }
        }
    }
}

extension View {
    func glassSurface(cornerRadius: CGFloat = 28, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius, tint: tint, interactive: interactive))
    }
}
