import SwiftUI

/// Thẻ khung chứa nội dung chuẩn macOS HIG dùng chung cho NekoTrans.
public struct NekoCard<Content: View>: View {
    public let content: Content
    public var cornerRadius: CGFloat = 8
    public var padding: CGFloat = 10
    public var backgroundColor: Color = Color.primary.opacity(0.035)
    public var borderColor: Color = Color.primary.opacity(0.08)
    public var borderWidth: CGFloat = 0.8
    public var hasHoverEffect: Bool = false

    @State private var isHovered: Bool = false

    public init(
        cornerRadius: CGFloat = 8,
        padding: CGFloat = 10,
        backgroundColor: Color = Color.primary.opacity(0.035),
        borderColor: Color = Color.primary.opacity(0.08),
        borderWidth: CGFloat = 0.8,
        hasHoverEffect: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.hasHoverEffect = hasHoverEffect
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .background(
                hasHoverEffect && isHovered
                    ? backgroundColor.opacity(1.3)
                    : backgroundColor
            )
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        hasHoverEffect && isHovered
                            ? borderColor.opacity(1.5)
                            : borderColor,
                        lineWidth: borderWidth
                    )
            )
            .onHover { hovering in
                if hasHoverEffect {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        isHovered = hovering
                    }
                }
            }
    }
}
