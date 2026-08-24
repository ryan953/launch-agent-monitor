import SwiftUI

/// A `.plain`/`.borderless`-like button style that adds a subtle rounded
/// background on hover (and a stronger one while pressed). Icon-only
/// borderless buttons otherwise give no visual cue they're clickable until
/// you actually click them — this makes hovering itself the cue.
struct HoverableButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 6
    var padding: CGFloat = 4

    func makeBody(configuration: Configuration) -> some View {
        HoverBody(configuration: configuration, cornerRadius: cornerRadius, padding: padding)
    }

    private struct HoverBody: View {
        let configuration: ButtonStyleConfiguration
        let cornerRadius: CGFloat
        let padding: CGFloat

        @State private var isHovering = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .padding(padding)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(fillColor)
                )
                .contentShape(Rectangle())
                .onHover { hovering in
                    isHovering = isEnabled && hovering
                }
        }

        private var fillColor: Color {
            guard isEnabled else { return .clear }
            if configuration.isPressed { return Color.primary.opacity(0.18) }
            if isHovering { return Color.primary.opacity(0.10) }
            return .clear
        }
    }
}

extension ButtonStyle where Self == HoverableButtonStyle {
    static var hoverable: HoverableButtonStyle { HoverableButtonStyle() }
}
